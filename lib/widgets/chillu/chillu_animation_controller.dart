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

  /// Friendly bounce when greeted or welcomed.
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
        _state = returnState;
        notifyListeners();
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
      case ChilluState.greeting:
        return const Duration(milliseconds: 1600);
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

  /// Sets Chillu to idle gentle breathing.
  void idle({bool force = true}) => triggerState(ChilluState.idle, duration: Duration.zero, force: force);

  /// Sets Chillu to attentive posture (focused on chat input/typing).
  void attentive({Duration? duration}) =>
      triggerState(ChilluState.attentive, duration: duration);

  /// Sets Chillu to active listening posture during voice recording.
  void listening({Duration? duration}) =>
      triggerState(ChilluState.listening, duration: duration);

  /// Triggers friendly greeting bounce.
  void greet({Duration? duration}) =>
      triggerState(ChilluState.greeting, duration: duration);

  /// Enters thinking state while awaiting assistant reply.
  void think({Duration? duration}) =>
      triggerState(ChilluState.thinking, duration: duration);

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
    _transientResetTimer?.cancel();
    _transientResetTimer = null;
    _state = ChilluState.sleepy;
    notifyListeners();
  }

  @override
  void dispose() {
    _transientResetTimer?.cancel();
    super.dispose();
  }
}
