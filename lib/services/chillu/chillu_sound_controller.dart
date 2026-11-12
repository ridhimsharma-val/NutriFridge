import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound effects controller for the Chillu mascot.
/// Manages sound playback, session greeting state, sound muting preference,
/// and prevents overlapping audio cues.
class ChilluSoundController {
  static final ChilluSoundController instance = ChilluSoundController._internal();

  ChilluSoundController._internal() {
    _initPreferences();
  }

  static const String _prefSoundEnabledKey = 'chillu_sound_enabled';

  AudioPlayer? _player;
  bool _isSoundEnabled = true;
  bool _hasGreetedThisSession = false;
  DateTime? _lastPlayedTime;

  /// ValueNotifier to allow UI components (like sound toggles) to rebuild reactively.
  final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);

  /// Whether Chillu sound effects are enabled.
  bool get isSoundEnabled => _isSoundEnabled;

  /// Whether Chillu has already chirped greeting in this session.
  bool get hasGreetedThisSession => _hasGreetedThisSession;

  /// Canonical 8-sound personality audio assets (~1.8–2.3s each, Celebrating ~2.35s).
  static const String entryJumpAsset = 'audio/chillu/01_entry_jump.wav';
  static const String attentiveAsset = 'audio/chillu/02_attentive.wav';
  static const String listeningAsset = 'audio/chillu/03_listening.wav';
  static const String thinkingAsset = 'audio/chillu/04_thinking.wav';
  static const String happyAsset = 'audio/chillu/05_happy.wav';
  static const String excitedAsset = 'audio/chillu/06_excited.wav';
  static const String celebratingAsset = 'audio/chillu/07_celebrating.wav';
  static const String confusedAsset = 'audio/chillu/08_confused.wav';

  /// Legacy alias constants for backwards compatibility.
  static const String greetingChirpAsset = 'audio/chillu/01_greeting_chirp.wav';
  static const String addItemPopAsset = 'audio/chillu/02_add_item_pop.wav';
  static const String thinkingPingAsset = 'audio/chillu/03_thinking_ping.wav';
  static const String processingShimmerAsset = 'audio/chillu/04_processing_shimmer.wav';
  static const String recipeFoundAsset = 'audio/chillu/05_recipe_found.wav';
  static const String mealLoggedSuccessAsset = 'audio/chillu/06_meal_logged_success.wav';
  static const String confusedBoopAsset = 'audio/chillu/07_confused_boop.wav';
  static const String sleepyYawnAsset = 'audio/chillu/08_sleepy_yawn.wav';

  AudioPlayer get _audioPlayer {
    _player ??= AudioPlayer();
    return _player!;
  }

  Future<void> _initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefSoundEnabledKey);
      if (saved != null) {
        _isSoundEnabled = saved;
        soundEnabledNotifier.value = saved;
      }
    } catch (e) {
      debugPrint('[ChilluSoundController] Failed to load sound preference: $e');
    }
  }

  /// Sets whether sounds are enabled and persists the preference.
  Future<void> setSoundEnabled(bool enabled) async {
    _isSoundEnabled = enabled;
    soundEnabledNotifier.value = enabled;
    if (!enabled && _player != null) {
      try {
        await _player!.stop();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSoundEnabledKey, enabled);
    } catch (e) {
      debugPrint('[ChilluSoundController] Failed to save sound preference: $e');
    }
  }

  /// Toggles the sound preference.
  Future<void> toggleSound() async {
    await setSoundEnabled(!_isSoundEnabled);
  }

  /// Resets session greeting state (e.g. for testing or new login).
  void resetSession() {
    _hasGreetedThisSession = false;
  }

  /// Core sound playback helper with throttling and overlap prevention.
  Future<void> _playSound(String assetPath, {Duration cooldown = const Duration(milliseconds: 300)}) async {
    if (!_isSoundEnabled) return;

    final now = DateTime.now();
    if (_lastPlayedTime != null && now.difference(_lastPlayedTime!) < cooldown) {
      // Prevent overlapping or spamming sounds
      return;
    }
    _lastPlayedTime = now;

    try {
      final player = _audioPlayer;
      // Stop any currently playing short effect to prevent audio cacophony
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (e) {
      // Non-blocking: Autoplay policies on Web or missing audio drivers should not crash the app
      debugPrint('[ChilluSoundController] Audio playback note ($assetPath): $e');
    }
  }

  // ===========================================================================
  // CANONICAL 8-SOUND PERSONALITY REACTIONS (~2s each, Celebrating ~2.35s)
  // ===========================================================================

  /// A. Entry Jump (~2.05s): Soft bubbly opening, warm ascending chime, light sparkling finish.
  /// Plays only once when entering the AI Assistant screen.
  Future<void> playEntryJump() async {
    if (_hasGreetedThisSession) return;
    _hasGreetedThisSession = true;
    await _playSound(entryJumpAsset, cooldown: const Duration(milliseconds: 1500));
  }

  /// B. Attentive (~2.00s): Gentle rising musical notes, soft bubbly accent, cheerful finishing note.
  /// Plays once when the user begins typing and Chillu enters Attentive.
  /// Does NOT replay on every keystroke or during the continuous loop.
  Future<void> playAttentive() async {
    await _playSound(attentiveAsset, cooldown: const Duration(milliseconds: 1800));
  }

  /// C. Listening (~2.00s): Gentle atmospheric opening, warm tonal pulses, soft finishing chime.
  /// Plays once when actual microphone recording begins. Does NOT loop.
  Future<void> playListening() async {
    await _playSound(listeningAsset, cooldown: const Duration(seconds: 2));
  }

  /// D. Thinking (~2.05s): Gentle rising and falling notes, soft sparkling tones, subtle unresolved finish.
  /// Plays once when Chillu enters Thinking. Does NOT replay during every processing update.
  Future<void> playThinking() async {
    await _playSound(thinkingAsset, cooldown: const Duration(seconds: 2));
  }

  /// E. Happy (~2.00s): Bright melodic notes, pleasant bubbly accents, warm uplifting finish.
  /// Plays on friendly, ordinary positive interactions.
  Future<void> playHappy() async {
    await _playSound(happyAsset, cooldown: const Duration(milliseconds: 1500));
  }

  /// F. Excited (~2.05s): Quick ascending musical sequence, playful sparkles, bright uplifting finish.
  /// Plays when the AI successfully finds or presents an appealing meal or recipe suggestion.
  Future<void> playExcited() async {
    await _playSound(excitedAsset, cooldown: const Duration(milliseconds: 1500));
  }

  /// G. Celebrating (~2.35s): Chillu's signature mini celebration sound.
  /// Joyful opening, layered sparkling chimes, cheerful melodic flourish, grand golden finish.
  /// Plays ONLY after successful confirmation of the corresponding action.
  Future<void> playCelebrating() async {
    await _playSound(celebratingAsset, cooldown: const Duration(milliseconds: 1800));
  }

  /// H. Confused (~2.00s): Cute puzzled sound: questioning notes, slight descending movement, soft unresolved finish.
  /// Plays when an AI response fails or cannot be generated.
  Future<void> playConfused() async {
    await _playSound(confusedAsset, cooldown: const Duration(milliseconds: 1500));
  }

  // ===========================================================================
  // LEGACY ALIASES (Delegating to the 8 canonical sound reactions)
  // ===========================================================================

  /// Legacy greeting chirp alias.
  Future<void> playGreetingChirp() => playEntryJump();

  /// Legacy add-item pop alias (delegates to signature Celebrating).
  Future<void> playAddItemPop() => playCelebrating();

  /// Legacy thinking ping alias.
  Future<void> playThinkingPing() => playThinking();

  /// Legacy processing shimmer alias.
  Future<void> playProcessingShimmer() => playThinking();

  /// Legacy recipe found alias (delegates to Excited).
  Future<void> playRecipeFound() => playExcited();

  /// Legacy meal logged success alias (delegates to signature Celebrating).
  Future<void> playMealLoggedSuccess() => playCelebrating();

  /// Legacy confused boop alias.
  Future<void> playConfusedBoop() => playConfused();

  /// Sleepy yawn: Optional empty or idle state.
  Future<void> playSleepyYawn() async {
    await _playSound(sleepyYawnAsset, cooldown: const Duration(seconds: 2));
  }

  /// Disposes the underlying AudioPlayer.
  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
