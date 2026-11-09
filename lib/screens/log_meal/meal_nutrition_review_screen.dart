import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../../services/auth/auth_service.dart';
import '../../services/meals/meal_tracking_service.dart';
import '../../services/meals/models/meal_models.dart';
import 'models/detected_food_item.dart';
import 'models/meal_nutrition_estimate.dart';
import 'services/fridge_inventory_service.dart';

/// Screen 3 of the Log Meal flow: Nutrition Review & Fridge Inventory Adjustment.
class MealNutritionReviewScreen extends StatefulWidget {
  final String mealName;
  final Uint8List? imageBytes;
  final XFile? imageFile;
  final List<DetectedFoodItem> detectedFoods;
  final MealNutritionEstimate? nutritionEstimate;
  final String? initialMealType;

  const MealNutritionReviewScreen({
    super.key,
    required this.mealName,
    this.imageBytes,
    this.imageFile,
    required this.detectedFoods,
    this.nutritionEstimate,
    this.initialMealType,
  });

  @override
  State<MealNutritionReviewScreen> createState() => _MealNutritionReviewScreenState();
}

class _MealNutritionReviewScreenState extends State<MealNutritionReviewScreen> {
  late String _mealName;
  late String _selectedMealType;
  late List<IngredientInventoryStatus> _inventoryStatuses;
  late MealNutritionEstimate _nutrition;
  bool _isMoreNutritionExpanded = false;
  bool _isLogging = false;
  String? _idempotencyKey;

  final List<String> _mealTypes = const [
    'Breakfast',
    'Lunch',
    'Snack',
    'Dinner',
  ];

  @override
  void initState() {
    super.initState();
    _mealName = widget.mealName.trim().isEmpty ? 'Paneer Rice Bowl' : widget.mealName;
    _selectedMealType = (widget.initialMealType != null && widget.initialMealType!.trim().isNotEmpty)
        ? widget.initialMealType!.trim()
        : _detectDefaultMealType();
    _nutrition = widget.nutritionEstimate ?? MealNutritionEstimate.fromIngredients(widget.detectedFoods);
    _inventoryStatuses = FridgeInventoryService.inspectIngredients(widget.detectedFoods);
  }

  /// Automatically picks a sensible default meal type based on the time of day.
  String _detectDefaultMealType() {
    final now = DateTime.now();
    final timeDec = now.hour + (now.minute / 60.0);

    if (timeDec < 11.5) return 'Breakfast';
    if (timeDec < 15.5) return 'Lunch';
    if (timeDec < 18.5) return 'Snack';
    return 'Dinner';
  }

  void _editMealName() {
    final controller = TextEditingController(text: _mealName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Edit Meal Name',
                style: AppTypography.cardTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7FAF8),
                  hintText: 'e.g. Paneer Rice Bowl',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final trimmed = controller.text.trim();
                        if (trimmed.isNotEmpty) {
                          setState(() {
                            _mealName = trimmed;
                          });
                        }
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onConfirmAndLogMeal() async {
    if (_isLogging) return;

    if (_mealName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a meal name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.detectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one food item before logging.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final hasInvalid = widget.detectedFoods.any((f) => f.amount <= 0);
    if (hasInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All ingredient quantities must be greater than zero.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLogging = true;
    });

    final nutrition = _nutrition;

    _idempotencyKey ??= MealTrackingService.generateIdempotencyKey();

    try {
      final deductions = <MealIngredientDeduction>[];
      for (final status in _inventoryStatuses) {
        final item = status.ingredient;
        final matched = status.matchingItem;
        final isRealUuid = matched != null &&
            matched.id.isNotEmpty &&
            !matched.id.startsWith('item_') &&
            !matched.id.startsWith('food_') &&
            !matched.id.startsWith('dairy_');
        final doDeduct = status.isSelected && status.canDeduct && isRealUuid;
        deductions.add(MealIngredientDeduction(
          name: item.name,
          requiredQuantity: item.amount,
          requiredUnit: item.unit,
          matchedFridgeItemId: doDeduct ? matched.id : null,
          deductQuantity: doDeduct ? item.amount : null,
          deductUnit: doDeduct ? item.unit : null,
          doDeduct: doDeduct,
        ));
      }

      await MockDataRepository.logMeal(
        mealType: _selectedMealType,
        mealName: _mealName.trim(),
        calories: nutrition.calories,
        protein: nutrition.proteinGrams,
        carbs: nutrition.carbsGrams,
        fat: nutrition.fatGrams,
        ingredients: widget.detectedFoods.map((f) => '${f.name} (${f.formattedQuantity})').toList(),
        timestamp: DateTime.now(),
        idempotencyKey: _idempotencyKey,
        ingredientDeductions: deductions,
      );

      // In unauthenticated / test mode only, deduct in-memory
      if (!AuthService.instance.isAuthenticated || AuthService.instance.currentUser == null) {
        FridgeInventoryService.deductSelected(_inventoryStatuses);
      }

      _idempotencyKey = null;

      if (!mounted) return;

      // 3. Navigate back to Dashboard
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }

      // 4. Show friendly confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Meal logged successfully.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLogging = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log meal: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _onConfirmAndLogMeal,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = _nutrition;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.neutralCharcoal,
          ),
          tooltip: 'Back to Meal Analysis',
          onPressed: () => Navigator.of(context).pop(_mealName),
        ),
        centerTitle: true,
        title: Text(
          'Nutrition Review',
          style: AppTypography.sectionTitle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralCharcoal,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header (Title & Subtitle)
                    Text(
                      'Your meal breakdown',
                      style: AppTypography.greeting.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.neutralCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Here's the estimated nutrition for your meal.",
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Meal Summary Card (Photo, Name, Meal Type Selection)
                    _buildMealSummaryCard(),

                    const SizedBox(height: 18),

                    // 3. Estimated Calories & Macronutrients
                    _buildNutritionOverview(nutrition),

                    const SizedBox(height: 18),

                    // 4. Ingredients Detected (with subtle action to return to Screen 2)
                    _buildIngredientsSummary(),

                    const SizedBox(height: 18),

                    // 5. Optional Additional Nutrition Details (Expandable)
                    _buildMoreNutritionDetails(nutrition),

                    const SizedBox(height: 18),

                    // 6. Fridge Inventory Adjustment (Update your fridge)
                    _buildFridgeInventorySection(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 7. Primary Action: Confirm & Log Meal
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  /// Compact meal summary containing photo, editable meal name, and meal type selector.
  Widget _buildMealSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Meal photo thumbnail
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.paleMint,
                  border: Border.all(color: AppColors.cardBorder, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: widget.imageBytes != null
                      ? Image.memory(
                          widget.imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.restaurant_rounded,
                            size: 24,
                            color: AppColors.forestGreen,
                          ),
                        )
                      : const Icon(
                          Icons.restaurant_rounded,
                          size: 24,
                          color: AppColors.forestGreen,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Meal Name with Edit affordance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _editMealName,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _mealName,
                              style: AppTypography.cardTitle.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: AppColors.neutralCharcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: AppColors.forestGreen,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap to rename',
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F4F2)),
          const SizedBox(height: 12),

          // Meal Type Selector Pills
          Text(
            'Meal type',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _mealTypes.map((type) {
              final bool isSelected = type == _selectedMealType;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type == _mealTypes.last ? 0 : 6.0,
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMealType = type;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (type == 'Snack' ? AppColors.peachLight : AppColors.paleMint)
                            : const Color(0xFFF6F9F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (type == 'Snack' ? AppColors.peachPrimary : AppColors.forestGreen)
                              : AppColors.cardBorder,
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (type == 'Snack' ? AppColors.peachPrimary : AppColors.forestGreen)
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _editNutrition() {
    final caloriesCtrl = TextEditingController(text: '${_nutrition.calories}');
    final proteinCtrl = TextEditingController(text: '${_nutrition.proteinGrams}');
    final carbsCtrl = TextEditingController(text: '${_nutrition.carbsGrams}');
    final fatCtrl = TextEditingController(text: '${_nutrition.fatGrams}');
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6DDD8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Nutrition Values', style: AppTypography.cardTitle),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: caloriesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Calories (kcal)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: proteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: carbsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Carbs (g)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fat (g)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final cal = int.tryParse(caloriesCtrl.text.trim());
                          final prot = int.tryParse(proteinCtrl.text.trim());
                          final carb = int.tryParse(carbsCtrl.text.trim());
                          final fat = int.tryParse(fatCtrl.text.trim());

                          if (cal == null || prot == null || carb == null || fat == null || cal < 0 || prot < 0 || carb < 0 || fat < 0) {
                            setDialogState(() {
                              localError = 'Please enter valid non-negative numbers.';
                            });
                            return;
                          }

                          setState(() {
                            _nutrition = _nutrition.copyWith(
                              calories: cal,
                              proteinGrams: prot,
                              carbsGrams: carb,
                              fatGrams: fat,
                              isEstimate: false,
                              isManual: true,
                            );
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Save Nutrition', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Clean, prominent estimated nutrition summary card (Calories & 3 Macronutrients).
  Widget _buildNutritionOverview(MealNutritionEstimate nutrition) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nutrition.isManual ? 'Meal Calories' : 'Estimated Calories',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.forestGreen),
                tooltip: 'Edit Nutrition',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: _editNutrition,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${nutrition.calories}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralCharcoal,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'kcal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: nutrition.isManual ? const Color(0xFFEFF6FF) : AppColors.paleMint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: nutrition.isManual ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                width: 0.8,
              ),
            ),
            child: Text(
              nutrition.isManual ? 'Manual Entry' : 'AI Estimate',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: nutrition.isManual ? const Color(0xFF1D4ED8) : AppColors.forestGreen,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F4F2)),
          const SizedBox(height: 16),

          // Three Macronutrients Row
          Row(
            children: [
              Expanded(
                child: _buildMacroItem(
                  label: 'Protein',
                  amount: '${nutrition.proteinGrams} g',
                  accentColor: AppColors.sageAccent,
                  bgColor: AppColors.paleMint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroItem(
                  label: 'Carbohydrates',
                  amount: '${nutrition.carbsGrams} g',
                  accentColor: AppColors.coralHighlight,
                  bgColor: AppColors.peachLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroItem(
                  label: 'Fat',
                  amount: '${nutrition.fatGrams} g',
                  accentColor: AppColors.amberPrimary,
                  bgColor: AppColors.amberLight,
                ),
              ),
            ],
          ),

          if (!nutrition.isManual) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    nutrition.estimateNote ?? 'Approximate nutrition • Actual values may vary',
                    style: AppTypography.subtitle.copyWith(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroItem({
    required String label,
    required String amount,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralCharcoal,
            ),
          ),
        ],
      ),
    );
  }

  /// Ingredients detected section with action to return to Screen 2.
  Widget _buildIngredientsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Ingredients detected',
                style: AppTypography.sectionTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralCharcoal,
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.of(context).pop(_mealName),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit ingredients',
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppColors.forestGreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: widget.detectedFoods.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: Color(0xFFF1F4F2),
            ),
            itemBuilder: (context, index) {
              final item = widget.detectedFoods[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Food thumbnail
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.imageAsset != null
                            ? Image.asset(
                                item.imageAsset!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.restaurant_rounded,
                                  size: 18,
                                  color: AppColors.sageAccent,
                                ),
                              )
                            : const Icon(
                                Icons.restaurant_rounded,
                                size: 18,
                                color: AppColors.sageAccent,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralCharcoal,
                        ),
                      ),
                    ),
                    Text(
                      item.formattedQuantity,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestGreen.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Compact expandable "More nutrition details" section.
  Widget _buildMoreNutritionDetails(MealNutritionEstimate nutrition) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isMoreNutritionExpanded = !_isMoreNutritionExpanded;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'More nutrition details',
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estimated values for reference',
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isMoreNutritionExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isMoreNutritionExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFF1F4F2)),
                  const SizedBox(height: 12),
                  _buildMicroNutrientRow('Dietary Fiber', '${nutrition.fiberGrams} g'),
                  const SizedBox(height: 8),
                  _buildMicroNutrientRow('Sugars', '${nutrition.sugarsGrams} g'),
                  const SizedBox(height: 8),
                  _buildMicroNutrientRow('Sodium', '${nutrition.sodiumMg} mg'),
                  const SizedBox(height: 8),
                  _buildMicroNutrientRow('Potassium', '${nutrition.potassiumMg} mg'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMicroNutrientRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Fridge inventory adjustment section with opt-in checkboxes.
  Widget _buildFridgeInventorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.kitchen_outlined,
                size: 20,
                color: AppColors.forestGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Update your fridge',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select ingredients that came from your tracked inventory.',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // List of ingredients with opt-in checkboxes
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _inventoryStatuses.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: Color(0xFFF1F4F2),
            ),
            itemBuilder: (context, index) {
              final status = _inventoryStatuses[index];
              final bool canDeduct = status.canDeduct;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Opt-in Checkbox
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: status.isSelected,
                        activeColor: AppColors.forestGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        onChanged: canDeduct
                            ? (val) {
                                setState(() {
                                  status.isSelected = val ?? false;
                                });
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Ingredient details & fridge status explanation
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${status.ingredient.name} — ${status.ingredient.formattedQuantity}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: canDeduct ? AppColors.neutralCharcoal : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            canDeduct && status.isSelected
                                ? 'Deducting ${status.ingredient.formattedQuantity} (${status.remainingPreview})'
                                : status.statusExplanation,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: canDeduct
                                  ? (status.isSelected ? AppColors.forestGreen : AppColors.textTertiary)
                                  : AppColors.textTertiary,
                              fontWeight: status.isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Prominent bottom confirmation button: "Confirm & Log Meal".
  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLogging ? null : _onConfirmAndLogMeal,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forestGreen,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.forestGreen.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLogging
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Confirm & Log Meal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Backwards compatibility alias for existing tests and routes
typedef MealNutritionReviewPlaceholderScreen = MealNutritionReviewScreen;
