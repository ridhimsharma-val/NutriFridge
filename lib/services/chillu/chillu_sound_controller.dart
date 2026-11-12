import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diagnostic status information for Chillu audio playback.
class ChilluAudioDiagnostics {
  final int loadedAssetsCount;
  final int totalAssetsCount;
  final bool isPlayerInitialized;
  final bool isAudioUnlocked;
  final String playbackStatus;
  final String? lastPlayedAsset;
  final DateTime? lastPlayedTime;
  final String? lastError;
  final bool isSoundEnabled;

  const ChilluAudioDiagnostics({
    required this.loadedAssetsCount,
    required this.totalAssetsCount,
    required this.isPlayerInitialized,
    required this.isAudioUnlocked,
    required this.playbackStatus,
    this.lastPlayedAsset,
    this.lastPlayedTime,
    this.lastError,
    required this.isSoundEnabled,
  });

  ChilluAudioDiagnostics copyWith({
    int? loadedAssetsCount,
    int? totalAssetsCount,
    bool? isPlayerInitialized,
    bool? isAudioUnlocked,
    String? playbackStatus,
    String? lastPlayedAsset,
    DateTime? lastPlayedTime,
    String? lastError,
    bool? isSoundEnabled,
  }) {
    return ChilluAudioDiagnostics(
      loadedAssetsCount: loadedAssetsCount ?? this.loadedAssetsCount,
      totalAssetsCount: totalAssetsCount ?? this.totalAssetsCount,
      isPlayerInitialized: isPlayerInitialized ?? this.isPlayerInitialized,
      isAudioUnlocked: isAudioUnlocked ?? this.isAudioUnlocked,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      lastPlayedAsset: lastPlayedAsset ?? this.lastPlayedAsset,
      lastPlayedTime: lastPlayedTime ?? this.lastPlayedTime,
      lastError: lastError,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
    );
  }
}

/// Sound effects controller for the Chillu mascot.
/// Manages sound playback, session greeting state, sound muting preference,
/// in-memory byte caching for Flutter Web reliability, browser audio context unlock,
/// and live diagnostic telemetry.
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
  bool _pendingEntryJump = false;
  bool _isAudioUnlocked = !kIsWeb; // Non-web platforms don't restrict autoplay
  DateTime? _lastPlayedTime;
  String? _lastPlayedAsset;
  String? _lastError;
  String _playbackStatus = 'Idle';

  final Map<String, Uint8List> _soundBytesCache = {};

  /// ValueNotifier to allow UI components (like sound toggles) to rebuild reactively.
  final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);

  /// ValueNotifier for live audio diagnostics used by the debug test panel.
  late final ValueNotifier<ChilluAudioDiagnostics> diagnosticsNotifier = ValueNotifier<ChilluAudioDiagnostics>(
    ChilluAudioDiagnostics(
      loadedAssetsCount: 0,
      totalAssetsCount: canonicalAssets.length,
      isPlayerInitialized: false,
      isAudioUnlocked: _isAudioUnlocked,
      playbackStatus: 'Initializing',
      lastPlayedAsset: null,
      lastPlayedTime: null,
      lastError: null,
      isSoundEnabled: true,
    ),
  );

  /// Whether Chillu sound effects are enabled.
  bool get isSoundEnabled => _isSoundEnabled;

  /// Whether Chillu has already chirped greeting in this session.
  bool get hasGreetedThisSession => _hasGreetedThisSession;

  /// Whether the browser audio context is unlocked.
  bool get isAudioUnlocked => _isAudioUnlocked;

  /// Whether entry jump is currently deferred awaiting user interaction.
  bool get isEntryJumpPending => _pendingEntryJump;

  /// Canonical 8-sound personality audio assets (~1.8–2.3s each, Celebrating ~2.35s).
  static const String entryJumpAsset = 'audio/chillu/01_entry_jump.wav';
  static const String attentiveAsset = 'audio/chillu/02_attentive.wav';
  static const String listeningAsset = 'audio/chillu/03_listening.wav';
  static const String thinkingAsset = 'audio/chillu/04_thinking.wav';
  static const String happyAsset = 'audio/chillu/05_happy.wav';
  static const String excitedAsset = 'audio/chillu/06_excited.wav';
  static const String celebratingAsset = 'audio/chillu/07_celebrating.wav';
  static const String confusedAsset = 'audio/chillu/08_confused.wav';

  /// All 8 canonical audio asset paths.
  static const List<String> canonicalAssets = [
    entryJumpAsset,
    attentiveAsset,
    listeningAsset,
    thinkingAsset,
    happyAsset,
    excitedAsset,
    celebratingAsset,
    confusedAsset,
  ];

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
    if (_player == null) {
      _player = AudioPlayer();
      try {
        _player!.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
      try {
        _player!.onPlayerComplete.listen((_) {
          _playbackStatus = 'Idle';
          _updateDiagnostics();
        });
      } catch (_) {}
      _updateDiagnostics();
    }
    return _player!;
  }

  void _updateDiagnostics() {
    diagnosticsNotifier.value = ChilluAudioDiagnostics(
      loadedAssetsCount: _soundBytesCache.length,
      totalAssetsCount: canonicalAssets.length,
      isPlayerInitialized: _player != null,
      isAudioUnlocked: _isAudioUnlocked,
      playbackStatus: _playbackStatus,
      lastPlayedAsset: _lastPlayedAsset,
      lastPlayedTime: _lastPlayedTime,
      lastError: _lastError,
      isSoundEnabled: _isSoundEnabled,
    );
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
    _updateDiagnostics();
  }

  /// Preloads all 8 sound personality audio files into memory as byte arrays.
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
    _playbackStatus = 'Idle';
    _updateDiagnostics();
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
    _updateDiagnostics();
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
    _pendingEntryJump = false;
  }

  /// Unlocks Web Audio context upon the first user interaction (pointer down / tap).
  /// If entry jump sound was deferred because of autoplay restrictions on initial load,
  /// this automatically plays it now.
  Future<void> unlockAudioContext() async {
    if (!_isAudioUnlocked) {
      _isAudioUnlocked = true;
      debugPrint('[ChilluSoundController] Web Audio Context unlocked on user gesture');
      try {
        await _audioPlayer.resume();
      } catch (_) {}
      _updateDiagnostics();
    }

    if (_pendingEntryJump && !_hasGreetedThisSession) {
      debugPrint('[ChilluSoundController] Playing deferred Entry Jump sound after gesture unlock');
      _pendingEntryJump = false;
      await playEntryJump(force: true);
    }
  }

  /// Core sound playback helper with throttling, byte caching, and web autoplay handling.
  Future<void> _playSound(
    String assetPath, {
    Duration cooldown = const Duration(milliseconds: 300),
    bool force = false,
  }) async {
    if (!_isSoundEnabled) {
      _playbackStatus = 'Muted';
      _updateDiagnostics();
      return;
    }

    final now = DateTime.now();
    if (!force && _lastPlayedTime != null && now.difference(_lastPlayedTime!) < cooldown) {
      // Prevent overlapping or spamming sounds
      return;
    }
    _lastPlayedTime = now;
    _lastPlayedAsset = assetPath;

    try {
      final player = _audioPlayer;

      // Stop any currently playing short effect to prevent audio cacophony
      try {
        player.stop().catchError((_) {});
      } catch (_) {}

      // Prefer playing from preloaded memory bytes on Web to bypass HTTP 404 dev server quirks
      Uint8List? bytes = _soundBytesCache[assetPath];
      if (bytes == null) {
        try {
          final byteData = await rootBundle.load('assets/$assetPath');
          bytes = byteData.buffer.asUint8List();
          _soundBytesCache[assetPath] = bytes;
        } catch (_) {}
      }

      _playbackStatus = 'Playing: ${assetPath.split('/').last}';
      _lastError = null;
      _updateDiagnostics();

      final Source source = (kIsWeb && bytes != null)
          ? BytesSource(bytes, mimeType: 'audio/wav')
          : AssetSource(assetPath);

      player.play(source).then((_) {
        _isAudioUnlocked = true;
        _updateDiagnostics();
      }).catchError((e) {
        _handlePlaybackError(assetPath, e);
      });
    } catch (e) {
      _handlePlaybackError(assetPath, e);
    }
  }

  void _handlePlaybackError(String assetPath, Object e) {
    final errStr = e.toString();
    debugPrint('[ChilluSoundController] Playback exception ($assetPath): $e');

    // Check if browser autoplay policy blocked playback
    if (errStr.contains('NotAllowedError') || errStr.contains('interact') || errStr.contains('user gesture')) {
      _isAudioUnlocked = false;
      _lastError = 'Autoplay blocked: awaiting user interaction';
      _playbackStatus = 'Awaiting User Gesture';
      if (assetPath == entryJumpAsset && !_hasGreetedThisSession) {
        _pendingEntryJump = true;
      }
    } else {
      _lastError = errStr;
      _playbackStatus = 'Error';
    }
    _updateDiagnostics();
  }

  /// Triggers a test sound playback directly from the debug panel, bypassing cooldowns.
  Future<void> testPlay(String assetPath) async {
    await unlockAudioContext();
    await _playSound(assetPath, force: true);
  }

  // ===========================================================================
  // CANONICAL 8-SOUND PERSONALITY REACTIONS (~2s each, Celebrating ~2.35s)
  // ===========================================================================

  /// A. Entry Jump (~2.05s): Soft bubbly opening, warm ascending chime, light sparkling finish.
  /// Plays only once when entering the AI Assistant screen.
  Future<void> playEntryJump({bool force = false}) async {
    if (!force && _hasGreetedThisSession) return;
    _hasGreetedThisSession = true;
    await _playSound(entryJumpAsset, cooldown: const Duration(milliseconds: 1500), force: force);
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
