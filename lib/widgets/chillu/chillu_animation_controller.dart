import 'dart:async';
import 'package:flutter/foundation.dart';

/// Interaction states for the Chillu mascot.
enum ChilluState {
  /// Gentle breathing and occasional blinking.
  idle,

  /// Friendly bounce when greeted or welcomed.
  greeting,

  /// Subtle head/body tilt while formulating thoughts.
  thinking,

  /// Gentle floating / hovering animation while AI request is in-flight.
  processing,

  /// Happy jump GIF when recipe recommendations or ideas are received.
  recipeFound,

  /// Short energetic bounce when groceries/ingredients are confirmed.
  itemAdded,

  /// Joyful jump GIF and celebration after meal logging succeeds.
  mealLogged,

  /// Confused expression / gentle tilt when an error or ambiguity occurs.
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
      _state == ChilluState.recipeFound || _state == ChilluState.mealLogged;

  /// Whether Chillu is currently floating in the processing state.
  bool get isProcessing => _state == ChilluState.processing;

  /// Triggers a state transition.
  /// If [duration] is provided or if the state is transient, automatically returns to [returnState] (defaults to idle)
  /// after the duration expires.
  void triggerState(
    ChilluState newState, {
    Duration? duration,
    ChilluState returnState = ChilluState.idle,
  }) {
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
      case ChilluState.greeting:
        return const Duration(milliseconds: 1600);
      case ChilluState.recipeFound:
        return const Duration(milliseconds: 2400);
      case ChilluState.mealLogged:
        return const Duration(milliseconds: 2600);
      case ChilluState.itemAdded:
        return const Duration(milliseconds: 1200);
      case ChilluState.error:
        return const Duration(milliseconds: 1800);
      case ChilluState.thinking:
        return const Duration(milliseconds: 2000);
      case ChilluState.idle:
      case ChilluState.processing:
      case ChilluState.sleepy:
        // Persistent states until explicitly changed
        return null;
    }
  }

  /// Sets Chillu to idle gentle breathing.
  void idle() => triggerState(ChilluState.idle, duration: Duration.zero);

  /// Triggers friendly greeting bounce.
  void greet({Duration? duration}) =>
      triggerState(ChilluState.greeting, duration: duration);

  /// Enters thinking state.
  void think({Duration? duration}) =>
      triggerState(ChilluState.thinking, duration: duration);

  /// Enters continuous processing floating state while request is active.
  void process() {
    _transientResetTimer?.cancel();
    _transientResetTimer = null;
    _state = ChilluState.processing;
    notifyListeners();
  }

  /// Triggers recipe found celebration jump GIF.
  void recipeFound({Duration? duration}) =>
      triggerState(ChilluState.recipeFound, duration: duration);

  /// Triggers item added bounce.
  void itemAdded({Duration? duration}) =>
      triggerState(ChilluState.itemAdded, duration: duration);

  /// Triggers meal logged celebration jump GIF.
  void mealLogged({Duration? duration}) =>
      triggerState(ChilluState.mealLogged, duration: duration);

  /// Triggers confused tilt / error expression.
  void confused({Duration? duration}) =>
      triggerState(ChilluState.error, duration: duration);

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
