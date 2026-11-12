const fs = require('fs');
const path = require('path');

const sampleRate = 44100;

function createWavBuffer(samples) {
  const dataSize = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataSize);

  // RIFF header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);

  // fmt subchunk
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // subchunk1 size
  buffer.writeUInt16LE(1, 20);  // PCM
  buffer.writeUInt16LE(1, 22);  // mono
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28); // byte rate
  buffer.writeUInt16LE(2, 32);  // block align
  buffer.writeUInt16LE(16, 34); // bits per sample

  // data subchunk
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);

  // Find max amplitude for peak normalization (-1.5 dBFS = 0.841)
  let maxAmp = 0;
  for (let i = 0; i < samples.length; i++) {
    const abs = Math.abs(samples[i]);
    if (abs > maxAmp) maxAmp = abs;
  }

  const targetPeak = 0.841;
  const normFactor = maxAmp > 0 ? (targetPeak / maxAmp) : 1.0;

  for (let i = 0; i < samples.length; i++) {
    const val = Math.max(-1.0, Math.min(1.0, samples[i] * normFactor));
    const intVal = Math.round(val * 32767);
    buffer.writeInt16LE(intVal, 44 + i * 2);
  }

  return buffer;
}

// Basic synthesis helpers
function marimba(buffer, startSec, freq, gain = 0.5, duration = 0.7) {
  const startSample = Math.floor(startSec * sampleRate);
  const totalSamples = Math.floor(duration * sampleRate);
  for (let i = 0; i < totalSamples && startSample + i < buffer.length; i++) {
    const t = i / sampleRate;
    const attack = Math.min(1.0, t / 0.005);
    const env = attack * Math.exp(-t / 0.32);
    const overtoneEnv = attack * Math.exp(-t / 0.09);
    const clickEnv = attack * Math.exp(-t / 0.02);
    const wave = Math.sin(2 * Math.PI * freq * t) * 0.72 +
                 Math.sin(2 * Math.PI * freq * 3.98 * t) * 0.20 * overtoneEnv +
                 Math.sin(2 * Math.PI * freq * 9.85 * t) * 0.08 * clickEnv;
    buffer[startSample + i] += wave * env * gain;
  }
}

function warmBell(buffer, startSec, freq, gain = 0.45, duration = 1.1) {
  const startSample = Math.floor(startSec * sampleRate);
  const totalSamples = Math.floor(duration * sampleRate);
  for (let i = 0; i < totalSamples && startSample + i < buffer.length; i++) {
    const t = i / sampleRate;
    const attack = Math.min(1.0, t / 0.005);
    const p1 = Math.sin(2 * Math.PI * freq * 1.0 * t) * 0.55 * Math.exp(-t / 0.75);
    const p2 = Math.sin(2 * Math.PI * freq * 2.756 * t) * 0.25 * Math.exp(-t / 0.45);
    const p3 = Math.sin(2 * Math.PI * freq * 5.404 * t) * 0.12 * Math.exp(-t / 0.25);
    const p4 = Math.sin(2 * Math.PI * freq * 8.933 * t) * 0.08 * Math.exp(-t / 0.12);
    buffer[startSample + i] += (p1 + p2 + p3 + p4) * attack * gain;
  }
}

function glockenspiel(buffer, startSec, freq, gain = 0.35, duration = 0.7) {
  const startSample = Math.floor(startSec * sampleRate);
  const totalSamples = Math.floor(duration * sampleRate);
  for (let i = 0; i < totalSamples && startSample + i < buffer.length; i++) {
    const t = i / sampleRate;
    const attack = Math.min(1.0, t / 0.002);
    const p1 = Math.sin(2 * Math.PI * freq * t) * 0.75 * Math.exp(-t / 0.55);
    const p2 = Math.sin(2 * Math.PI * freq * 3.01 * t) * 0.18 * Math.exp(-t / 0.22);
    const p3 = Math.sin(2 * Math.PI * freq * 6.02 * t) * 0.07 * Math.exp(-t / 0.09);
    buffer[startSample + i] += (p1 + p2 + p3) * attack * gain;
  }
}

function bubblePop(buffer, startSec, startFreq = 340, endFreq = 780, gain = 0.45, duration = 0.12) {
  const startSample = Math.floor(startSec * sampleRate);
  const totalSamples = Math.floor(duration * sampleRate);
  let phase = 0;
  for (let i = 0; i < totalSamples && startSample + i < buffer.length; i++) {
    const t = i / sampleRate;
    const progress = t / duration;
    const freq = startFreq + (endFreq - startFreq) * Math.sin(progress * Math.PI * 0.5);
    phase += 2 * Math.PI * freq / sampleRate;
    const env = Math.sin(progress * Math.PI) * Math.exp(-progress * 2.2);
    buffer[startSample + i] += Math.sin(phase) * env * gain;
  }
}

function warmAtmosphere(buffer, startSec, freqs, duration = 1.6, gain = 0.18) {
  const startSample = Math.floor(startSec * sampleRate);
  const totalSamples = Math.floor(duration * sampleRate);
  for (let i = 0; i < totalSamples && startSample + i < buffer.length; i++) {
    const t = i / sampleRate;
    const attack = Math.min(1.0, t / (duration * 0.30));
    const release = Math.max(0.0, 1.0 - (t - duration * 0.60) / (duration * 0.40));
    const env = Math.min(attack, release);
    let wave = 0;
    for (const f of freqs) {
      wave += Math.sin(2 * Math.PI * f * t) * 0.65 + Math.sin(2 * Math.PI * f * 2.0 * t) * 0.25;
    }
    buffer[startSample + i] += (wave / freqs.length) * env * gain;
  }
}

function applyFades(buffer, fadeOutSec = 0.25) {
  const fadeSamples = Math.floor(fadeOutSec * sampleRate);
  const startFade = buffer.length - fadeSamples;
  for (let i = 0; i < fadeSamples; i++) {
    const progress = i / fadeSamples;
    const factor = Math.cos(progress * Math.PI * 0.5);
    buffer[startFade + i] *= factor;
  }
  // Subtle 5ms fade in to eliminate any DC click
  const inSamples = Math.floor(0.005 * sampleRate);
  for (let i = 0; i < inSamples; i++) {
    buffer[i] *= (i / inSamples);
  }
}

// -------------------------------------------------------------
// Note constants (Hz)
// -------------------------------------------------------------
const C4 = 261.63, D4 = 293.66, E4 = 329.63, F4 = 349.23, G4 = 392.00, A4 = 440.00, Bb4 = 466.16, B4 = 493.88;
const C5 = 523.25, D5 = 587.33, E5 = 659.25, F5 = 698.46, G5 = 783.99, A5 = 880.00, Bb5 = 932.33, B5 = 987.77;
const C6 = 1046.50, D6 = 1174.66, E6 = 1318.51, F6 = 1396.91, G6 = 1567.98, A6 = 1760.00, B6 = 1975.53;
const C7 = 2093.00, D7 = 2349.32, E7 = 2637.02;

// -------------------------------------------------------------
// Sound Generators
// -------------------------------------------------------------

// 1. ENTRY JUMP (~2.05s)
// Soft bubbly opening, warm ascending chime, light sparkling finish
function generateEntryJump() {
  const duration = 2.05;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Bubbly opening (0.0s - 0.4s)
  bubblePop(samples, 0.02, 280, 680, 0.40, 0.11);
  bubblePop(samples, 0.14, 380, 880, 0.42, 0.10);

  // Warm ascending chime (0.28s - 1.2s): F4 -> A4 -> C5 -> F5
  marimba(samples, 0.28, F4, 0.38, 0.6);
  warmBell(samples, 0.28, F4, 0.25, 0.8);

  marimba(samples, 0.46, A4, 0.40, 0.6);
  warmBell(samples, 0.46, A4, 0.28, 0.8);

  marimba(samples, 0.66, C5, 0.44, 0.7);
  warmBell(samples, 0.66, C5, 0.35, 0.9);

  marimba(samples, 0.88, F5, 0.50, 0.8);
  warmBell(samples, 0.88, F5, 0.42, 1.1);

  // Light sparkling finish (1.05s - 2.0s)
  glockenspiel(samples, 1.08, A5, 0.32, 0.6);
  glockenspiel(samples, 1.22, C6, 0.35, 0.6);
  glockenspiel(samples, 1.38, E6, 0.38, 0.6);
  glockenspiel(samples, 1.54, A6, 0.40, 0.5);

  applyFades(samples, 0.25);
  return samples;
}

// 2. ATTENTIVE (~2.00s)
// Curious & playful: gentle rising musical notes, soft bubbly accent, cheerful finishing note
function generateAttentive() {
  const duration = 2.00;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Gentle rising musical notes on marimba & soft bell: D4 -> G4 -> B4
  marimba(samples, 0.05, D4, 0.42, 0.6);
  marimba(samples, 0.26, G4, 0.45, 0.6);
  warmBell(samples, 0.26, G4, 0.25, 0.8);
  marimba(samples, 0.48, B4, 0.48, 0.6);
  warmBell(samples, 0.48, B4, 0.30, 0.8);

  // Soft bubbly accent (0.75s - 1.1s)
  bubblePop(samples, 0.74, 420, 920, 0.38, 0.10);
  glockenspiel(samples, 0.82, D5, 0.34, 0.5);

  // Cheerful finishing note (1.05s - 2.0s): G5 + D6 warm chime ring-out
  marimba(samples, 1.05, G5, 0.50, 0.8);
  warmBell(samples, 1.05, G5, 0.45, 0.95);
  glockenspiel(samples, 1.15, D6, 0.28, 0.7);

  applyFades(samples, 0.25);
  return samples;
}

// 3. LISTENING (~2.00s)
// Soft, airy listening sound: gentle atmospheric opening, warm tonal pulses, soft finishing chime
function generateListening() {
  const duration = 2.00;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Gentle atmospheric opening (0.0s - 1.8s)
  warmAtmosphere(samples, 0.02, [E4, B4, E5], 1.7, 0.22);

  // Warm tonal pulses (attentive acoustic ear pulses): G#4 -> B4 -> E5
  warmBell(samples, 0.30, G4 * 1.05946, 0.36, 0.85); // G#4
  marimba(samples, 0.30, G4 * 1.05946, 0.30, 0.6);

  warmBell(samples, 0.68, B4, 0.40, 0.90);
  marimba(samples, 0.68, B4, 0.32, 0.6);

  warmBell(samples, 1.05, E5, 0.44, 0.95);
  glockenspiel(samples, 1.05, B5, 0.25, 0.7);

  // Soft finishing chime (1.35s - 2.0s)
  glockenspiel(samples, 1.35, E6, 0.30, 0.65);

  applyFades(samples, 0.25);
  return samples;
}

// 4. THINKING (~2.05s)
// Thoughtful and slightly mysterious: gentle rising and falling notes, soft sparkling tones, subtle unresolved finish
function generateThinking() {
  const duration = 2.05;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Subtle contemplative background pad
  warmAtmosphere(samples, 0.05, [A4, E5], 1.7, 0.16);

  // Gentle rising and falling notes on marimba & soft bell: A4 -> C5 -> B4 -> E4
  marimba(samples, 0.08, A4, 0.40, 0.6);
  warmBell(samples, 0.08, A4, 0.24, 0.8);

  marimba(samples, 0.36, C5, 0.44, 0.6);
  warmBell(samples, 0.36, C5, 0.28, 0.8);

  marimba(samples, 0.66, B4, 0.42, 0.6);
  warmBell(samples, 0.66, B4, 0.26, 0.8);

  marimba(samples, 0.94, E4, 0.38, 0.7);
  warmBell(samples, 0.94, E4, 0.24, 0.9);

  // Soft sparkling tones (1.1s - 1.6s)
  glockenspiel(samples, 1.15, E6, 0.28, 0.55);
  glockenspiel(samples, 1.30, G6, 0.26, 0.55);

  // Subtle unresolved musical finish (1.45s - 2.05s): D5 + F#5 suspended contemplation
  warmBell(samples, 1.45, D5, 0.38, 0.60);
  glockenspiel(samples, 1.48, F5 * 1.05946, 0.28, 0.55); // F#5

  applyFades(samples, 0.25);
  return samples;
}

// 5. HAPPY (~2.00s)
// Cheerful and heartwarming: bright melodic notes, pleasant bubbly accents, warm uplifting finish
function generateHappy() {
  const duration = 2.00;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Bright melodic notes: C5 -> E5 -> G5 -> A5
  marimba(samples, 0.05, C5, 0.44, 0.6);
  warmBell(samples, 0.05, C5, 0.28, 0.8);

  marimba(samples, 0.25, E5, 0.46, 0.6);
  warmBell(samples, 0.25, E5, 0.30, 0.8);

  marimba(samples, 0.46, G5, 0.48, 0.7);
  warmBell(samples, 0.46, G5, 0.34, 0.9);

  // Pleasant bubbly accents (0.65s - 0.95s)
  bubblePop(samples, 0.68, 480, 980, 0.36, 0.09);
  bubblePop(samples, 0.82, 580, 1150, 0.38, 0.09);

  // Warm uplifting finish (0.95s - 2.0s): C5 + G5 + E6 major chord sustain
  marimba(samples, 0.98, C5, 0.40, 0.8);
  warmBell(samples, 0.98, G5, 0.46, 1.0);
  glockenspiel(samples, 1.02, E6, 0.42, 0.95);
  glockenspiel(samples, 1.25, G6, 0.28, 0.70);

  applyFades(samples, 0.25);
  return samples;
}

// 6. EXCITED (~2.05s)
// Energetic version of Happy: quick ascending sequence, playful sparkles, bright uplifting finish
function generateExcited() {
  const duration = 2.05;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Quick energetic ascending musical sequence: G4 -> C5 -> E5 -> G5 -> C6
  marimba(samples, 0.04, G4, 0.42, 0.45);
  marimba(samples, 0.16, C5, 0.45, 0.45);
  warmBell(samples, 0.16, C5, 0.25, 0.6);

  marimba(samples, 0.28, E5, 0.48, 0.50);
  warmBell(samples, 0.28, E5, 0.28, 0.7);

  marimba(samples, 0.42, G5, 0.50, 0.55);
  warmBell(samples, 0.42, G5, 0.32, 0.8);

  marimba(samples, 0.58, C6, 0.55, 0.70);
  warmBell(samples, 0.58, C6, 0.42, 0.95);

  // Playful sparkles dancing cascade (0.75s - 1.35s)
  glockenspiel(samples, 0.76, E6, 0.36, 0.5);
  glockenspiel(samples, 0.88, G6, 0.38, 0.5);
  glockenspiel(samples, 1.00, B6, 0.36, 0.5);
  glockenspiel(samples, 1.12, C7, 0.40, 0.6);

  // Bright uplifting finish (1.25s - 2.05s)
  warmBell(samples, 1.25, G5, 0.40, 0.8);
  glockenspiel(samples, 1.28, E6, 0.36, 0.75);
  glockenspiel(samples, 1.35, C7, 0.35, 0.7);

  applyFades(samples, 0.25);
  return samples;
}

// 7. CELEBRATING (~2.35s)
// Signature sound! Mini celebration: joyful opening, layered sparkling chimes, melodic flourish, memorable finish
function generateCelebrating() {
  const duration = 2.35;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Joyful triumphant opening fanfare: F4 -> C5 -> F5
  warmBell(samples, 0.05, F4, 0.40, 0.8);
  marimba(samples, 0.05, F4, 0.42, 0.5);

  warmBell(samples, 0.22, C5, 0.45, 0.8);
  marimba(samples, 0.22, C5, 0.46, 0.5);

  warmBell(samples, 0.40, F5, 0.50, 0.9);
  marimba(samples, 0.40, F5, 0.52, 0.6);

  // Layered sparkling chimes cascade: A5 -> C6 -> F6 -> A6
  glockenspiel(samples, 0.58, A5, 0.36, 0.6);
  glockenspiel(samples, 0.72, C6, 0.38, 0.6);
  glockenspiel(samples, 0.86, F6, 0.42, 0.7);
  glockenspiel(samples, 1.00, A6, 0.45, 0.7);

  // Cheerful melodic flourish (1.15s - 1.55s)
  marimba(samples, 1.16, G5, 0.44, 0.45);
  warmBell(samples, 1.16, G5, 0.30, 0.6);

  marimba(samples, 1.30, A5, 0.46, 0.45);
  warmBell(samples, 1.30, A5, 0.32, 0.6);

  // Memorable, satisfying grand finishing chord (1.45s - 2.35s): F5 + C6 + F6 with gold shimmer
  marimba(samples, 1.48, F5, 0.48, 0.85);
  warmBell(samples, 1.48, F5, 0.44, 0.85);
  warmBell(samples, 1.48, C6, 0.46, 0.85);
  glockenspiel(samples, 1.52, F6, 0.42, 0.80);
  glockenspiel(samples, 1.70, C7, 0.32, 0.65);

  applyFades(samples, 0.28);
  return samples;
}

// 8. CONFUSED (~2.00s)
// Cute puzzled sound: 2-3 questioning notes, slight descending movement, soft unresolved finish
function generateConfused() {
  const duration = 2.00;
  const samples = new Float32Array(Math.floor(duration * sampleRate));

  // Questioning notes: curious marimba & hollow bell: Bb4 -> D5
  marimba(samples, 0.08, Bb4, 0.46, 0.6);
  warmBell(samples, 0.08, Bb4, 0.26, 0.7);

  marimba(samples, 0.35, D5, 0.48, 0.6);
  warmBell(samples, 0.35, D5, 0.28, 0.7);

  // Slight descending musical movement: D5 -> C5 -> A4 with curious hollow wooden pop
  bubblePop(samples, 0.62, 540, 360, 0.36, 0.12); // subtle curious downward bubble

  marimba(samples, 0.68, C5, 0.44, 0.55);
  warmBell(samples, 0.68, C5, 0.25, 0.7);

  marimba(samples, 0.98, A4, 0.42, 0.65);
  warmBell(samples, 0.98, A4, 0.28, 0.8);

  // Soft unresolved finish (1.25s - 2.0s): F4 + Bb4 questioning interval
  warmBell(samples, 1.28, F4, 0.38, 0.70);
  glockenspiel(samples, 1.30, Bb4, 0.32, 0.68);

  applyFades(samples, 0.25);
  return samples;
}

// -------------------------------------------------------------
// Output Generation
// -------------------------------------------------------------
const outputDir = path.join(__dirname, '..', 'assets', 'audio', 'chillu');

const sounds = [
  { name: '01_entry_jump.wav', legacy: ['01_greeting_chirp.wav'], gen: generateEntryJump, desc: 'Entry Jump (~2.05s)' },
  { name: '02_attentive.wav', legacy: [], gen: generateAttentive, desc: 'Attentive (~2.00s)' },
  { name: '03_listening.wav', legacy: [], gen: generateListening, desc: 'Listening (~2.00s)' },
  { name: '04_thinking.wav', legacy: ['03_thinking_ping.wav', '04_processing_shimmer.wav'], gen: generateThinking, desc: 'Thinking (~2.05s)' },
  { name: '05_happy.wav', legacy: [], gen: generateHappy, desc: 'Happy (~2.00s)' },
  { name: '06_excited.wav', legacy: ['05_recipe_found.wav'], gen: generateExcited, desc: 'Excited (~2.05s)' },
  { name: '07_celebrating.wav', legacy: ['06_meal_logged_success.wav', '02_add_item_pop.wav'], gen: generateCelebrating, desc: 'Celebrating (~2.35s)' },
  { name: '08_confused.wav', legacy: ['07_confused_boop.wav'], gen: generateConfused, desc: 'Confused (~2.00s)' },
];

console.log('Generating Chillu 8-Sound Personality Audio Collection...');
for (const s of sounds) {
  const samples = s.gen();
  const buffer = createWavBuffer(samples);
  const mainPath = path.join(outputDir, s.name);
  fs.writeFileSync(mainPath, buffer);
  console.log(`✓ Generated ${s.name} (${s.desc}, ${(samples.length / sampleRate).toFixed(2)}s, ${buffer.length} bytes)`);

  // Also write to legacy aliases for seamless backwards compatibility
  for (const leg of s.legacy) {
    const legPath = path.join(outputDir, leg);
    fs.writeFileSync(legPath, buffer);
    console.log(`  ↳ Updated legacy alias: ${leg}`);
  }
}

console.log('All Chillu sound personality assets successfully synthesized!');
