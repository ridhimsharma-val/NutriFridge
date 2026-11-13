import 'package:flutter/material.dart';
import '../../../models/nutrition_data.dart';
import '../../../services/chillu/chillu_sound_controller.dart';
import '../../meal_detail/models/meal_detail_data.dart';
import '../models/guided_cooking_timer_state.dart';
import '../utils/cooking_timer_helper.dart';
import '../widgets/guided_cooking_completion_view.dart';
import '../widgets/guided_cooking_preparation_view.dart';
import '../widgets/guided_cooking_step_view.dart';

/// Phase stages of the Guided Cooking experience
enum GuidedCookingPhase {
  preparation,
  stepByStep,
  completed,
}

/// Full-screen Interactive Guided Cooking interface (v1).
/// Allows users to follow recipes step-by-step with preparation checklists,
/// accurate background timers, progress indicators, and completion meal logging.
class GuidedCookingScreen extends StatefulWidget {
  final MealDetailInfo meal;
  final RecipeRecommendation recommendation;
  final Future<void> Function(MealDetailInfo meal)? onLogMeal;

  const GuidedCookingScreen({
    super.key,
    required this.meal,
    required this.recommendation,
    this.onLogMeal,
  });

  @override
  State<GuidedCookingScreen> createState() => _GuidedCookingScreenState();
}

class _GuidedCookingScreenState extends State<GuidedCookingScreen> {
  GuidedCookingPhase _currentPhase = GuidedCookingPhase.preparation;
  int _currentStepIndex = 0;
  final Set<int> _completedStepIndices = {};
  final Map<int, StepTimerState> _stepTimers = {};
  bool _isLogging = false;

  int get _totalSteps => widget.meal.preparationSteps.isNotEmpty
      ? widget.meal.preparationSteps.length
      : 1;

  @override
  void initState() {
    super.initState();
    _initializeTimers();
  }

  @override
  void dispose() {
    for (final timer in _stepTimers.values) {
      timer.dispose();
    }
    super.dispose();
  }

  /// Discovers and configures timers for steps with explicit durations.
  /// Never invents or fabricates timers for steps without duration.
  void _initializeTimers() {
    final steps = widget.meal.preparationSteps;
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final seconds = CookingTimerHelper.parseDurationSeconds(
        explicitTime: step.time,
        instruction: step.instruction,
      );
      if (seconds != null && seconds > 0) {
        _stepTimers[i] = StepTimerState(
          stepIndex: i,
          totalSeconds: seconds,
        );
      }
    }
  }

  void _handleBeginCooking() {
    setState(() {
      _currentPhase = GuidedCookingPhase.stepByStep;
      _currentStepIndex = 0;
    });
  }

  void _handlePreviousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    } else {
      // Step 0 previous returns back to preparation checklist
      setState(() {
        _currentPhase = GuidedCookingPhase.preparation;
      });
    }
  }

  void _handleNextStep() {
    setState(() {
      _completedStepIndices.add(_currentStepIndex);
      if (_currentStepIndex < _totalSteps - 1) {
        _currentStepIndex++;
      } else {
        // Final step completed -> transition to Completion Screen
        _currentPhase = GuidedCookingPhase.completed;
      }
    });
  }

  void _handleBackToPrep() {
    setState(() {
      _currentPhase = GuidedCookingPhase.preparation;
    });
  }

  void _handleClose() {
    Navigator.of(context).pop();
  }

  void _handleStartTimer(int stepIndex) {
    final timer = _stepTimers[stepIndex];
    if (timer == null) return;
    timer.start(
      onTick: () {
        if (mounted) setState(() {});
      },
      onComplete: () {
        if (mounted) {
          setState(() {});
          _notifyTimerComplete(stepIndex);
        }
      },
    );
    setState(() {});
  }

  void _handlePauseTimer(int stepIndex) {
    final timer = _stepTimers[stepIndex];
    if (timer == null) return;
    timer.pause(
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    setState(() {});
  }

  void _handleResumeTimer(int stepIndex) {
    final timer = _stepTimers[stepIndex];
    if (timer == null) return;
    timer.resume(
      onTick: () {
        if (mounted) setState(() {});
      },
      onComplete: () {
        if (mounted) {
          setState(() {});
          _notifyTimerComplete(stepIndex);
        }
      },
    );
    setState(() {});
  }

  void _handleResetTimer(int stepIndex) {
    final timer = _stepTimers[stepIndex];
    if (timer == null) return;
    timer.reset(
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    setState(() {});
  }

  void _notifyTimerComplete(int stepIndex) {
    try {
      ChilluSoundController.instance.playCelebrating();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Step ${stepIndex + 1} timer completed!'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleLogMeal() async {
    if (_isLogging) return;
    setState(() {
      _isLogging = true;
    });

    try {
      if (widget.onLogMeal != null) {
        await widget.onLogMeal!(widget.meal);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentPhase) {
      case GuidedCookingPhase.preparation:
        return GuidedCookingPreparationView(
          meal: widget.meal,
          onBeginCooking: _handleBeginCooking,
          onClose: _handleClose,
        );

      case GuidedCookingPhase.stepByStep:
        final currentTimer = _stepTimers[_currentStepIndex];

        return GuidedCookingStepView(
          meal: widget.meal,
          currentStepIndex: _currentStepIndex,
          totalSteps: _totalSteps,
          completedSteps: _completedStepIndices,
          timerState: currentTimer,
          onPrevious: _handlePreviousStep,
          onNext: _handleNextStep,
          onBackToPrep: _handleBackToPrep,
          onClose: _handleClose,
          onStartTimer: currentTimer != null ? () => _handleStartTimer(_currentStepIndex) : null,
          onPauseTimer: currentTimer != null ? () => _handlePauseTimer(_currentStepIndex) : null,
          onResumeTimer: currentTimer != null ? () => _handleResumeTimer(_currentStepIndex) : null,
          onResetTimer: currentTimer != null ? () => _handleResetTimer(_currentStepIndex) : null,
        );

      case GuidedCookingPhase.completed:
        return GuidedCookingCompletionView(
          meal: widget.meal,
          onLogMeal: _handleLogMeal,
          onReturnToRecipe: _handleClose,
          isLogging: _isLogging,
        );
    }
  }
}
