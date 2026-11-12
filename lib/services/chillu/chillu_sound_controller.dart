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

  /// Audio asset relative paths (without `assets/` prefix, as required by audioplayers `AssetSource`).
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

  /// Greeting chirp: Plays when AI Assistant is opened, once per session.
  Future<void> playGreetingChirp() async {
    if (_hasGreetedThisSession) return;
    _hasGreetedThisSession = true;
    await _playSound(greetingChirpAsset);
  }

  /// Add-item pop: Plays when inventory addition is confirmed.
  Future<void> playAddItemPop() async {
    await _playSound(addItemPopAsset);
  }

  /// Thinking ping: Short thinking transition, sparingly.
  Future<void> playThinkingPing() async {
    await _playSound(thinkingPingAsset, cooldown: const Duration(milliseconds: 500));
  }

  /// Processing shimmer: Plays when an AI request begins (plays once per request).
  Future<void> playProcessingShimmer() async {
    await _playSound(processingShimmerAsset, cooldown: const Duration(seconds: 1));
  }

  /// Recipe found: Plays when recipe recommendation response is received.
  Future<void> playRecipeFound() async {
    await _playSound(recipeFoundAsset);
  }

  /// Meal logged success: Plays ONLY after backend `log_meal_transaction` confirms success.
  Future<void> playMealLoggedSuccess() async {
    await _playSound(mealLoggedSuccessAsset);
  }

  /// Confused boop: Plays on appropriate recoverable interaction error or clarification prompt.
  Future<void> playConfusedBoop() async {
    await _playSound(confusedBoopAsset);
  }

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
