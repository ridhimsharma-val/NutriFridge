import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound effects controller for the Chillu mascot.
/// Manages sound playback for Chillu's two designated audio states:
/// - Excited: Played on appealing meal / recipe recommendations.
/// - Celebrating: Played on confirmed user actions (adding groceries, logging meals).
/// All other mascot states remain completely silent while retaining full visual animations.
class ChilluSoundController {
  static final ChilluSoundController instance = ChilluSoundController._internal();

  ChilluSoundController._internal() {
    _initPreferences();
    preloadSounds();
  }

  static const String _prefSoundEnabledKey = 'chillu_sound_enabled';

  AudioPlayer? _player;
  bool _isSoundEnabled = true;
  bool _hasGreetedThisSession = false;
  bool _isAudioUnlocked = !kIsWeb;
  DateTime? _lastPlayedTime;

  final Map<String, Uint8List> _soundBytesCache = {};

  /// ValueNotifier to allow UI components (like sound toggles) to rebuild reactively.
  final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);

  /// Whether Chillu sound effects are enabled.
  bool get isSoundEnabled => _isSoundEnabled;

  /// Whether Chillu has already greeted in this session.
  bool get hasGreetedThisSession => _hasGreetedThisSession;

  /// Whether the browser audio context is unlocked.
  bool get isAudioUnlocked => _isAudioUnlocked;

  // ===========================================================================
  // DESIGNATED AUDIO ASSETS (ONLY TWO SOUNDS PRODUCE AUDIO)
  // ===========================================================================

  /// A. Excited (~2.05s): Soft, uplifting ascending chime for meal recommendations.
  static const String excitedAsset = 'audio/chillu/06_excited.wav';

  /// B. Celebrating (~2.35s): Chillu's signature mini-celebration chime for confirmed user actions.
  static const String celebratingAsset = 'audio/chillu/07_celebrating.wav';

  /// The active audio assets preloaded and cached for instant playback.
  static const List<String> canonicalAssets = [
    excitedAsset,
    celebratingAsset,
  ];

  // Legacy aliases mapped to the two active sounds
  static const String recipeFoundAsset = excitedAsset;
  static const String mealLoggedSuccessAsset = celebratingAsset;
  static const String addItemPopAsset = celebratingAsset;

  AudioPlayer get _audioPlayer {
    if (_player == null) {
      _player = AudioPlayer();
      try {
        _player!.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }
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

  /// Preloads the two sound effect audio files into memory as byte arrays.
  /// On Flutter Web, serving bytes via data URIs avoids 404 HTTP asset lookups
  /// and eliminates network latency during sound playback.
  Future<void> preloadSounds() async {
    for (final asset in canonicalAssets) {
      if (!_soundBytesCache.containsKey(asset)) {
        try {
          final byteData = await rootBundle.load('assets/$asset');
          _soundBytesCache[asset] = byteData.buffer.asUint8List();
        } catch (e) {
          debugPrint('[ChilluSoundController] Note: Could not preload asset $asset: $e');
        }
      }
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

  /// Resets session greeting state.
  void resetSession() {
    _hasGreetedThisSession = false;
  }

  /// Unlocks Web Audio context upon user interaction (pointer down / tap).
  Future<void> unlockAudioContext() async {
    if (!_isAudioUnlocked) {
      _isAudioUnlocked = true;
      try {
        await _audioPlayer.resume();
      } catch (_) {}
    }
  }

  /// Core sound playback helper with throttling, memory byte caching, and web autoplay handling.
  Future<void> _playSound(
    String assetPath, {
    Duration cooldown = const Duration(milliseconds: 300),
    bool force = false,
  }) async {
    if (!_isSoundEnabled) {
      debugPrint('[ChilluSoundController] Sound muted; skipping playback of $assetPath');
      return;
    }

    final now = DateTime.now();
    if (!force && _lastPlayedTime != null && now.difference(_lastPlayedTime!) < cooldown) {
      // Prevent overlapping or spamming sounds
      return;
    }
    _lastPlayedTime = now;

    try {
      final player = _audioPlayer;

      // Stop any currently playing effect
      try {
        player.stop().catchError((_) {});
      } catch (_) {}

      // Prefer playing from preloaded memory bytes on Web
      Uint8List? bytes = _soundBytesCache[assetPath];
      if (bytes == null) {
        try {
          final byteData = await rootBundle.load('assets/$assetPath');
          bytes = byteData.buffer.asUint8List();
          _soundBytesCache[assetPath] = bytes;
        } catch (_) {}
      }

      final Source source = (kIsWeb && bytes != null)
          ? BytesSource(bytes, mimeType: 'audio/wav')
          : AssetSource(assetPath);

      player.play(source).then((_) {
        _isAudioUnlocked = true;
        debugPrint('[ChilluSoundController] Playing sound: $assetPath');
      }).catchError((e) {
        debugPrint('[ChilluSoundController] Playback exception ($assetPath): $e');
      });
    } catch (e) {
      debugPrint('[ChilluSoundController] Playback exception ($assetPath): $e');
    }
  }

  // ===========================================================================
  // ACTIVE SOUND EFFECTS (EXCITED & CELEBRATING ONLY)
  // ===========================================================================

  /// A. Excited: Quick ascending musical sequence for meal/recipe suggestions.
  /// Plays once when entering the Excited state. Does NOT replay during the animation loop.
  Future<void> playExcited() async {
    await _playSound(excitedAsset, cooldown: const Duration(milliseconds: 1500));
  }

  /// B. Celebrating: Chillu's signature mini-celebration sound.
  /// Plays only after an important user action is confirmed (e.g. adding grocery, logging meal).
  Future<void> playCelebrating() async {
    await _playSound(celebratingAsset, cooldown: const Duration(milliseconds: 1800));
  }

  // Active legacy aliases delegating to Excited & Celebrating
  Future<void> playRecipeFound() => playExcited();
  Future<void> playAddItemPop() => playCelebrating();
  Future<void> playMealLoggedSuccess() => playCelebrating();

  // ===========================================================================
  // COMPLETELY DISABLED SOUND STATES (SILENT NO-OPS)
  // Visual animations remain fully functional; audio playback is suppressed.
  // ===========================================================================

  /// Entry Jump: Silent.
  Future<void> playEntryJump({bool force = false}) async {
    _hasGreetedThisSession = true;
  }

  /// Attentive: Silent.
  Future<void> playAttentive() async {}

  /// Listening: Silent.
  Future<void> playListening() async {}

  /// Thinking: Silent.
  Future<void> playThinking() async {}

  /// Happy: Silent.
  Future<void> playHappy() async {}

  /// Confused: Silent.
  Future<void> playConfused() async {}

  /// Legacy greeting chirp alias: Silent.
  Future<void> playGreetingChirp() => playEntryJump();

  /// Legacy thinking ping alias: Silent.
  Future<void> playThinkingPing() async {}

  /// Legacy processing shimmer alias: Silent.
  Future<void> playProcessingShimmer() async {}

  /// Legacy confused boop alias: Silent.
  Future<void> playConfusedBoop() async {}

  /// Sleepy yawn: Silent.
  Future<void> playSleepyYawn() async {}

  /// Disposes the underlying AudioPlayer.
  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
