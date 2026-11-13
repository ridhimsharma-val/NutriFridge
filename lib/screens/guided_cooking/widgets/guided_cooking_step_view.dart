import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/food_image/food_image_model.dart';
import '../../../services/food_image/food_image_service.dart';
import '../../meal_detail/models/meal_detail_data.dart';
import '../models/guided_cooking_timer_state.dart';
import '../utils/cooking_timer_helper.dart';
import '../utils/step_ingredient_helper.dart';
import '../utils/step_instruction_parser.dart';

/// Interactive Step-by-Step Cooking View displaying one cooking instruction at a time.
/// Redesigned with an editorial cookbook aesthetic:
/// - Prominent cooking visual relevant to the active step
/// - Structured action heading & clean instruction (no raw markdown markers)
/// - Visual ingredient chips with quantities
/// - Non-overflowing responsive bottom navigation bar anchored via Scaffold
class GuidedCookingStepView extends StatelessWidget {
  final MealDetailInfo meal;
  final int currentStepIndex;
  final int totalSteps;
  final Set<int> completedSteps;
  final StepTimerState? timerState;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBackToPrep;
  final VoidCallback onClose;
  final VoidCallback? onStartTimer;
  final VoidCallback? onPauseTimer;
  final VoidCallback? onResumeTimer;
  final VoidCallback? onResetTimer;

  const GuidedCookingStepView({
    super.key,
    required this.meal,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.completedSteps,
    this.timerState,
    required this.onPrevious,
    required this.onNext,
    required this.onBackToPrep,
    required this.onClose,
    this.onStartTimer,
    this.onPauseTimer,
    this.onResumeTimer,
    this.onResetTimer,
  });

  @override
  Widget build(BuildContext context) {
    final step = meal.preparationSteps.isNotEmpty && currentStepIndex < meal.preparationSteps.length
        ? meal.preparationSteps[currentStepIndex]
        : RecipePreparationStep(
            stepNumber: currentStepIndex + 1,
            instruction: 'Prepare and cook ingredients according to your preferred cooking method.',
          );

    final relevantIngredients = StepIngredientHelper.findRelevantIngredients(
      instruction: step.instruction,
      ingredients: meal.ingredients,
    );

    final parsedInstruction = StepInstructionParser.parse(
      rawInstruction: step.instruction,
      stepNumber: step.stepNumber,
    );

    final isFirstStep = currentStepIndex == 0;
    final isLastStep = currentStepIndex >= totalSteps - 1;
    final progress = totalSteps > 0 ? (currentStepIndex + 1) / totalSteps : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.primaryForest, size: 24),
          onPressed: onClose,
          tooltip: 'Exit Guided Cooking',
        ),
        title: Text(
          'Step ${currentStepIndex + 1} of $totalSteps',
          key: const ValueKey('step_counter_title'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryForest,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: onBackToPrep,
            icon: const Icon(Icons.checklist_rounded, size: 18, color: AppColors.primaryForest),
            label: const Text(
              'Prep',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryForest,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return LinearProgressIndicator(
                key: const ValueKey('step_progress_bar'),
                value: value,
                backgroundColor: const Color(0xFFE2EBE5),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryForest),
                minHeight: 4,
              );
            },
          ),
        ),
      ),
      // Scrollable content body takes the exact remaining vertical space
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Step Indicator Badge & Completed Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant_rounded, size: 14, color: AppColors.primaryForest),
                      const SizedBox(width: 6),
                      Text(
                        'STEP ${(currentStepIndex + 1).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryForest,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (completedSteps.contains(currentStepIndex))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // 2. Cooking Visual Hero Card
            _buildCookingVisual(relevantIngredients),

            const SizedBox(height: 16),

            // 3. Editorial Cookbook Instruction Card
            _buildInstructionCard(step, parsedInstruction),

            // 4. Ingredients for this Step
            if (relevantIngredients.isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildRelevantIngredientsSection(relevantIngredients),
            ],

            // 5. Step Timer Card (Only when duration is specified)
            if (timerState != null) ...[
              const SizedBox(height: 18),
              _buildTimerCard(timerState!),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      // Anchored bottom navigation bar - impossible to overflow body
      bottomNavigationBar: _buildBottomNavigation(
        context: context,
        isFirstStep: isFirstStep,
        isLastStep: isLastStep,
      ),
    );
  }

  /// Large visual card relevant to the active instruction step
  Widget _buildCookingVisual(List<MealIngredientItem> relevantIngredients) {
    // 1. Resolve image source:
    // If relevant ingredients exist, use the primary ingredient photograph
    String? resolvedImageUrl;
    String? caption;

    if (relevantIngredients.isNotEmpty) {
      final primaryIng = relevantIngredients.first;
      final img = FoodImageService.instance.getImageSync(
        name: primaryIng.name,
        type: FoodEntityType.ingredient,
      );
      if (!img.isPlaceholder && img.imageUrl.isNotEmpty) {
        resolvedImageUrl = img.imageUrl;
        caption = primaryIng.name;
      }
    }

    // 2. Fall back to meal recipe photograph if no individual ingredient image was found
    if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
      if (meal.imageUrl.isNotEmpty) {
        resolvedImageUrl = meal.imageUrl;
        caption = meal.name;
      }
    }

    return Container(
      width: double.infinity,
      height: 175,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EBE5), width: 1.0),
        boxShadow: const [AppColors.softShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty)
            _buildImageWidget(resolvedImageUrl)
          else
            _buildVisualPlaceholder(),

          // Dark gradient vignette for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),

          // Caption label at bottom of image
          if (caption != null && caption.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.kitchen_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildVisualPlaceholder(),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildVisualPlaceholder(),
    );
  }

  Widget _buildVisualPlaceholder() {
    return Container(
      color: const Color(0xFFE8F2EC),
      child: const Center(
        child: Icon(Icons.outdoor_grill_rounded, size: 48, color: Color(0xFF81A68D)),
      ),
    );
  }

  /// Editorial Cookbook Instruction Card with prominent action heading and clean instruction
  Widget _buildInstructionCard(RecipePreparationStep step, ParsedStepInstruction parsed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EBE5), width: 1.0),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Heading (e.g. "ASSEMBLE THE BOWL", "SAUTÉ TOMATOES")
          Text(
            parsed.actionHeading.toUpperCase(),
            key: const ValueKey('step_action_heading'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryForest,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F2)),
          const SizedBox(height: 12),

          // Clean cooking instruction text - no raw markdown markers
          Text(
            parsed.cleanInstruction,
            key: const ValueKey('step_instruction_text'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
              height: 1.55,
              letterSpacing: -0.15,
            ),
          ),

          // Temperature Callout
          if (step.temperature != null && step.temperature!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildHeatCallout(step.temperature!),
          ],

          // Chef Tip Callout
          if (step.tip != null && step.tip!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildTipCallout(step.tip!),
          ],
        ],
      ),
    );
  }

  /// Compact visual cards for ingredients involved in this step
  Widget _buildRelevantIngredientsSection(List<MealIngredientItem> ingredients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredients for this step',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryForest,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ingredients.map((ing) {
            final img = FoodImageService.instance.getImageSync(
              name: ing.name,
              type: FoodEntityType.ingredient,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD4E7D9), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ingredient Mini Thumbnail
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF7ED),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC8E6C9), width: 0.8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: !img.isPlaceholder && img.imageUrl.isNotEmpty
                        ? _buildImageWidget(img.imageUrl)
                        : const Center(
                            child: Icon(Icons.eco_rounded, size: 14, color: AppColors.primaryForest),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Name and Quantity
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ing.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        ing.recipeQuantityText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeatCallout(String heat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFEA580C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Heat: $heat',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCallout(String tip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.0),
            child: Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF16A34A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF166534),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(StepTimerState timer) {
    final countdownStr = CookingTimerHelper.formatCountdown(timer.remainingSeconds);
    final isDone = timer.isCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? const Color(0xFF86EFAC) : const Color(0xFFE2EBE5),
          width: 1.2,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 18,
                    color: isDone ? const Color(0xFF16A34A) : AppColors.primaryForest,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Step Timer (${CookingTimerHelper.formatBadge(timer.totalSeconds)})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDone ? const Color(0xFF16A34A) : AppColors.primaryForest,
                    ),
                  ),
                ],
              ),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Finished!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Digital Countdown Display
          Text(
            countdownStr,
            key: const ValueKey('step_timer_countdown'),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
              color: isDone
                  ? const Color(0xFF16A34A)
                  : (timer.isRunning ? AppColors.primaryForest : const Color(0xFF1E293B)),
            ),
          ),

          const SizedBox(height: 14),

          // Timer Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!timer.isRunning && !timer.isPaused && !isDone)
                // Start Button
                ElevatedButton.icon(
                  key: const ValueKey('start_timer_btn'),
                  onPressed: onStartTimer,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Start Timer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else if (timer.isRunning) ...[
                // Pause Button
                ElevatedButton.icon(
                  key: const ValueKey('pause_timer_btn'),
                  onPressed: onPauseTimer,
                  icon: const Icon(Icons.pause_rounded, size: 20),
                  label: const Text('Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 10),
                // Reset Button
                OutlinedButton.icon(
                  key: const ValueKey('reset_timer_btn'),
                  onPressed: onResetTimer,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (timer.isPaused) ...[
                // Resume Button
                ElevatedButton.icon(
                  key: const ValueKey('resume_timer_btn'),
                  onPressed: onResumeTimer,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 10),
                // Reset Button
                OutlinedButton.icon(
                  key: const ValueKey('reset_timer_btn'),
                  onPressed: onResetTimer,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (isDone) ...[
                // Completed State Reset/Restart
                OutlinedButton.icon(
                  key: const ValueKey('reset_timer_btn'),
                  onPressed: onResetTimer,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Restart Timer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryForest,
                    side: const BorderSide(color: AppColors.primaryForest),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Responsive, non-overflowing bottom navigation bar anchored at bottom
  Widget _buildBottomNavigation({
    required BuildContext context,
    required bool isFirstStep,
    required bool isLastStep,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2EBE5), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -3),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Previous Step Button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  key: const ValueKey('previous_step_btn'),
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryForest,
                    side: const BorderSide(color: Color(0xFFD4E7D9), width: 1.2),
                    backgroundColor: isFirstStep ? Colors.transparent : const Color(0xFFF6FAF7),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isFirstStep ? 'Prep' : 'Previous',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Next Step / Complete Button
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('next_step_btn'),
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isLastStep ? 'Complete Cooking' : 'Next Step',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
