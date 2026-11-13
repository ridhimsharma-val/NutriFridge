import 'dart:async';
import 'package:flutter/foundation.dart';

/// Interaction states for the Chillu mascot.
enum ChilluState {
  /// Gentle breathing and occasional blinking.
  idle,

  /// Attentive posture when user focuses on chat input or types.
  attentive,

  /// Active listening posture when voice recording starts.
  listening,

  /// Cheerful entry hop when the AI Assistant screen is opened.
  entryJump,

  /// Expressive friendly greeting sequence (upward lift, 3-cycle playful wave, independent sprout bounce, smiling eyes, natural settling).
  greeting,

  /// Subtle head/body tilt while formulating thoughts.
  thinking,

  /// Gentle floating / hovering animation while AI request is in-flight.
  processing,

  /// Cheerful body bounce and happy expression on friendly/ordinary positive interaction.
  happy,

  /// Energetic jump, excited sparkle eyes, lively leaf bounce on meal/recipe suggestions.
  excited,

  /// Noticeable celebratory jump after confirmed actions (groceries added, meal logged).
  celebrating,

  /// Noticeable head tilt, questioning eye expression, asymmetrical leaf tilt when clarification is needed.
  confused,

  /// Happy jump GIF when recipe recommendations or ideas are received (legacy alias for excited).
  recipeFound,

  /// Short energetic bounce when groceries/ingredients are confirmed (legacy alias).
  itemAdded,

  /// Joyful jump GIF and celebration after meal logging succeeds (legacy alias for celebrating).
  mealLogged,

  /// Confused expression / gentle tilt when clarification is needed (legacy alias).
  error,

  /// Relaxed sleepy posture for empty / idle fridge moments.
  sleepy,
}

/// Controller managing Chillu's animation state and transient transitions.
class ChilluAnimationController extends ChangeNotifier {
  ChilluState _state;
  Timer? _transientResetTimer;
  Timer? _wakeUpFallbackTimer;
  ChilluState? _wakeUpDestination;
  bool _isWakingUp = false;

  ChilluAnimationController({ChilluState initialState = ChilluState.idle})
      : _state = initialState;

  /// The current mascot state.
  ChilluState get state => _state;

  /// Whether Chillu is in a transient celebration jump state (which uses the animated GIF).
  bool get isCelebrationJump =>
      _state == ChilluState.celebrating || _state == ChilluState.mealLogged;

  /// Whether Chillu is currently floating in the processing state.
  bool get isProcessing => _state == ChilluState.processing;

  /// Whether Chillu is currently playing a transient reaction.
  bool get isReacting => _transientResetTimer != null;

  /// Whether Chillu is currently performing its dedicated wake-up reaction from Sleepy.
  bool get isWakingUp => _isWakingUp;

  /// Target destination state to enter once wake-up completes.
  ChilluState? get wakeUpDestination => _wakeUpDestination;

  /// Priority scale for states:
  /// 1. Celebrating (8)
  /// 2. Excited (7)
  /// 3. Confused (6)
  /// 4. Happy (5)
  /// 5. Thinking (4)
  /// 6. Listening (3)
  /// 7. Attentive (2)
  /// 8. Idle (1)
  int _statePriority(ChilluState s) {
    switch (s) {
      case ChilluState.celebrating:
      case ChilluState.mealLogged:
        return 8;
      case ChilluState.excited:
      case ChilluState.recipeFound:
        return 7;
      case ChilluState.confused:
      case ChilluState.error:
        return 6;
      case ChilluState.happy:
      case ChilluState.itemAdded:
        return 5;
      case ChilluState.thinking:
      case ChilluState.processing:
        return 4;
      case ChilluState.listening:
        return 3;
      case ChilluState.attentive:
      case ChilluState.greeting:
      case ChilluState.entryJump:
        return 2;
      case ChilluState.idle:
      case ChilluState.sleepy:
        return 1;
    }
  }

  /// Triggers a state transition.
  /// If an active transient reaction with higher priority is running, lower priority transitions are ignored
  /// unless [force] is true.
  /// If [duration] is provided or if the state is transient, automatically returns to [returnState] (defaults to idle)
  /// after the duration expires.
  void triggerState(
    ChilluState newState, {
    Duration? duration,
    ChilluState returnState = ChilluState.idle,
    bool force = false,
  }) {
    if (!force && _transientResetTimer != null && _statePriority(newState) < _statePriority(_state)) {
      return;
    }

    _transientResetTimer?.cancel();
    _transientResetTimer = null;

    _state = newState;
    notifyListeners();

    final effectiveDuration = duration ?? _defaultDurationForState(newState);
    if (effectiveDuration != null) {
      _transientResetTimer = Timer(effectiveDuration, () {
        _transientResetTimer = null;
        if (_state == newState) {
          if (returnState != ChilluState.idle) {
            triggerState(returnState, returnState: ChilluState.idle);
          } else {
            _state = ChilluState.idle;
            notifyListeners();
          }
        }
      });
    }
  }

  Duration? _defaultDurationForState(ChilluState s) {
    switch (s) {
      case ChilluState.happy:
        return const Duration(milliseconds: 1500);
      case ChilluState.excited:
      case ChilluState.recipeFound:
        return const Duration(milliseconds: 2000);
      case ChilluState.celebrating:
      case ChilluState.mealLogged:
        return const Duration(milliseconds: 2600);
      case ChilluState.confused:
      case ChilluState.error:
        return const Duration(milliseconds: 2200);
      case ChilluState.itemAdded:
        return const Duration(milliseconds: 2200);
      case ChilluState.entryJump:
        return const Duration(milliseconds: 520);
      case ChilluState.greeting:
        return const Duration(milliseconds: 2000);
      case ChilluState.idle:
      case ChilluState.attentive:
      case ChilluState.listening:
      case ChilluState.thinking:
      case ChilluState.processing:
      case ChilluState.sleepy:
        // Persistent states driven by actual application state
        return null;
    }
  }

  /// Initiates a visible wake-up reaction from Sleepy state before landing in [destinationState].
  void wakeUp({ChilluState destinationState = ChilluState.idle}) {
    if (_state != ChilluState.sleepy && !_isWakingUp) return;
    if (kDebugMode) {
      debugPrint('[Chillu] Initiating wake-up reaction -> target destination: $destinationState');
    }
    _transientResetTimer?.cancel();
    _transientResetTimer = null;
    _wakeUpDestination = destinationState;
    _isWakingUp = true;
    _wakeUpFallbackTimer?.cancel();
    // Safety fallback timer if no mounted mascot drives completion (e.g. headless unit tests)
    _wakeUpFallbackTimer = Timer(const Duration(milliseconds: 1050), completeWakeUp);
    notifyListeners();
  }

  /// Concludes the wake-up reaction and transitions into the target destination state.
  void completeWakeUp() {
    _wakeUpFallbackTimer?.cancel();
    _wakeUpFallbackTimer = null;
    if (!_isWakingUp) return;
    _isWakingUp = false;
    final dest = _wakeUpDestination ?? ChilluState.idle;
    _wakeUpDestination = null;
    _state = dest;
    if (kDebugMode) {
      debugPrint('[Chillu] Wake-up reaction completed -> entered destination: $dest');
    }
    notifyListeners();
  }

  /// Sets Chillu to idle gentle breathing.
  void idle({bool force = true}) {
    if (_state == ChilluState.sleepy || _isWakingUp) {
      wakeUp(destinationState: ChilluState.idle);
      return;
    }
    triggerState(ChilluState.idle, duration: Duration.zero, force: force);
  }

  /// Sets Chillu to attentive posture (focused on chat input/typing).
  void attentive({Duration? duration}) {
    if (_state == ChilluState.sleepy || _isWakingUp) {
      wakeUp(destinationState: ChilluState.attentive);
      return;
    }
    triggerState(ChilluState.attentive, duration: duration);
  }

  /// Sets Chillu to active listening posture during voice recording.
  void listening({Duration? duration}) {
    if (_state == ChilluState.sleepy || _isWakingUp) {
      wakeUp(destinationState: ChilluState.listening);
      return;
    }
    triggerState(ChilluState.listening, duration: duration);
  }

  /// Triggers expressive friendly greeting sequence.
  void greet({Duration? duration}) {
    if (_state == ChilluState.sleepy || _isWakingUp) {
      wakeUp(destinationState: ChilluState.greeting);
      return;
    }
    triggerState(ChilluState.greeting, duration: duration);
  }

  /// Triggers the entry jump (elastic vertical hop).
  void entryJump({Duration? duration, ChilluState returnState = ChilluState.greeting}) {
    if (_state == ChilluState.sleepy || _isWakingUp) {
      wakeUp(destinationState: ChilluState.entryJump);
      return;
    }
    triggerState(ChilluState.entryJump, duration: duration, returnState: returnState);
  }

  /// Triggers the full entry sequence when user enters the AI Assistant screen:
  /// 1. Entry Jump plays first (520ms)
  /// 2. Automatically transitions into Greeting (2000ms)
  /// 3. After Greeting finishes, transitions into Idle
  void playEntrySequence() {
    entryJump(returnState: ChilluState.greeting);
  }

  /// Enters thinking state while awaiting assistant reply.
  void think({Duration? duration}) {
    if (_state == ChilluState.sleepy || _isWakingUp) {
      wakeUp(destinationState: ChilluState.thinking);
      return;
    }
    triggerState(ChilluState.thinking, duration: duration);
  }

  /// Enters continuous processing floating state while request is active.
  void process() {
    _transientResetTimer?.cancel();
    _transientResetTimer = null;
    _state = ChilluState.processing;
    notifyListeners();
  }

  /// Triggers cheerful Happy reaction.
  void happy({Duration? duration, ChilluState returnState = ChilluState.idle}) =>
      triggerState(ChilluState.happy, duration: duration, returnState: returnState);

  /// Triggers energetic Excited reaction.
  void excited({Duration? duration, ChilluState returnState = ChilluState.idle}) =>
      triggerState(ChilluState.excited, duration: duration, returnState: returnState);

  /// Triggers full Celebrating reaction.
  void celebrating({Duration? duration, ChilluState returnState = ChilluState.idle}) =>
      triggerState(ChilluState.celebrating, duration: duration, returnState: returnState);

  /// Triggers curious Confused reaction.
  /// If [persistent] is true, Chillu remains in Confused state until explicitly transitioned
  /// (e.g. while an AI response error remains active).
  void confused({
    Duration? duration,
    ChilluState returnState = ChilluState.idle,
    bool persistent = false,
  }) {
    if (_state == ChilluState.confused && _transientResetTimer == null && persistent) {
      // Already in persistent Confused state; do not restart repeatedly for the same error
      return;
    }
    if (persistent) {
      _transientResetTimer?.cancel();
      _transientResetTimer = null;
      _state = ChilluState.confused;
      notifyListeners();
      return;
    }
    triggerState(ChilluState.confused, duration: duration, returnState: returnState);
  }

  /// Triggers recipe found excited reaction (legacy alias for excited).
  void recipeFound({Duration? duration, ChilluState returnState = ChilluState.idle}) =>
      excited(duration: duration, returnState: returnState);

  /// Triggers item added celebration reaction (legacy alias for celebrating).
  void itemAdded({Duration? duration, ChilluState returnState = ChilluState.idle}) =>
      celebrating(duration: duration, returnState: returnState);

  /// Triggers meal logged celebration reaction (legacy alias for celebrating).
  void mealLogged({Duration? duration, ChilluState returnState = ChilluState.idle}) =>
      celebrating(duration: duration, returnState: returnState);

  /// Sets sleepy idle state.
  void sleepy() {
    if (kDebugMode) {
      debugPrint('[Chillu] Transitioning into Sleepy state');
    }
    _transientResetTimer?.cancel();
    _transientResetTimer = null;
    _wakeUpFallbackTimer?.cancel();
    _wakeUpFallbackTimer = null;
    _isWakingUp = false;
    _wakeUpDestination = null;
    _state = ChilluState.sleepy;
    notifyListeners();
  }

  @override
  void dispose() {
    _transientResetTimer?.cancel();
    _wakeUpFallbackTimer?.cancel();
    super.dispose();
  }
}
