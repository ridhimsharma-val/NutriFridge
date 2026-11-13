import 'dart:async';
import 'package:flutter/foundation.dart';

/// State representation for an individual cooking step timer.
class StepTimerState {
  final int stepIndex;
  final int totalSeconds;
  int remainingSeconds;
  bool isRunning;
  bool isPaused;
  bool isCompleted;
  Timer? _timer;

  StepTimerState({
    required this.stepIndex,
    required this.totalSeconds,
  })  : remainingSeconds = totalSeconds,
        isRunning = false,
        isPaused = false,
        isCompleted = false;

  /// Starts or resumes the countdown
  void start({VoidCallback? onTick, VoidCallback? onComplete}) {
    if (isRunning) return;
    if (remainingSeconds <= 0) {
      remainingSeconds = totalSeconds;
      isCompleted = false;
    }

    isRunning = true;
    isPaused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 1) {
        remainingSeconds--;
        onTick?.call();
      } else {
        remainingSeconds = 0;
        isRunning = false;
        isPaused = false;
        isCompleted = true;
        timer.cancel();
        _timer = null;
        onTick?.call();
        onComplete?.call();
      }
    });
  }

  /// Pauses the running timer
  void pause({VoidCallback? onTick}) {
    if (!isRunning) return;
    _timer?.cancel();
    _timer = null;
    isRunning = false;
    isPaused = true;
    onTick?.call();
  }

  /// Resumes the paused timer
  void resume({VoidCallback? onTick, VoidCallback? onComplete}) {
    start(onTick: onTick, onComplete: onComplete);
  }

  /// Resets the timer back to its initial duration
  void reset({VoidCallback? onTick}) {
    _timer?.cancel();
    _timer = null;
    remainingSeconds = totalSeconds;
    isRunning = false;
    isPaused = false;
    isCompleted = false;
    onTick?.call();
  }

  /// Disposes active background timer resources
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
