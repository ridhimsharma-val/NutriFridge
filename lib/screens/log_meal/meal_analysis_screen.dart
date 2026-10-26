import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'meal_nutrition_review_screen.dart';
import 'models/detected_food_item.dart';
import 'models/meal_nutrition_estimate.dart';

/// Screen 2 of the Log Meal flow: Meal Analysis & Portion Review.
/// Allows the user to inspect identified items, adjust portions, rename the meal,
/// or add missing items before reviewing nutrition.
class MealAnalysisScreen extends StatefulWidget {
  final Uint8List? imageBytes;
  final XFile? imageFile;
  final String initialMealName;
  final List<DetectedFoodItem>? initialFoods;

  const MealAnalysisScreen({
    super.key,
    this.imageBytes,
    this.imageFile,
    this.initialMealName = 'Paneer Rice Bowl',
    this.initialFoods,
  });

  @override
  State<MealAnalysisScreen> createState() => _MealAnalysisScreenState();
}

class _MealAnalysisScreenState extends State<MealAnalysisScreen> {
  late String _mealName;
  late List<DetectedFoodItem> _detectedFoods;

  @override
  void initState() {
    super.initState();
    _mealName = widget.initialMealName;
    _detectedFoods = widget.initialFoods != null
        ? List.from(widget.initialFoods!)
        : DetectedFoodItem.initialSampleDetection;
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
                    borderSide: const BorderSide(color: AppColors.tealPrimary, width: 1.5),
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
                        backgroundColor: AppColors.tealPrimary,
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

  void _editFoodItem(int index) {
    final item = _detectedFoods[index];
    final amountController = TextEditingController(
      text: item.amount % 1 == 0 ? item.amount.toInt().toString() : item.amount.toString(),
    );
    String selectedUnit = item.unit;
    final List<String> units = ['g', 'ml', 'pieces', 'cup', 'bowl', 'tbsp'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                    'Edit Portion — ${item.name}',
                    style: AppTypography.cardTitle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 16),

                  // Numeric quantity field
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
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
                        borderSide: const BorderSide(color: AppColors.tealPrimary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Unit selection pills
                  Text(
                    'Unit',
                    style: AppTypography.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: units.map((u) {
                      final bool isSelected = u == selectedUnit;
                      return ChoiceChip(
                        label: Text(u),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedUnit = u;
                            });
                          }
                        },
                        selectedColor: AppColors.tealLight,
                        backgroundColor: const Color(0xFFF2F6F3),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.tealPrimary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.tealPrimary : Colors.transparent,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),
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
                            final parsed = double.tryParse(amountController.text.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() {
                                _detectedFoods[index] = item.copyWith(
                                  amount: parsed,
                                  unit: selectedUnit,
                                );
                              });
                            }
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tealPrimary,
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
          );
        },
      ),
    );
  }

  void _addFoodItem() {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '100');
    String selectedUnit = 'g';
    final List<String> units = ['g', 'ml', 'pieces', 'cup', 'bowl', 'tbsp'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                    'Add Food Item',
                    style: AppTypography.cardTitle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Food name',
                      hintText: 'e.g. Avocado, Olive Oil',
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
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
                        borderSide: const BorderSide(color: AppColors.tealPrimary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Estimated Quantity',
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
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
                        borderSide: const BorderSide(color: AppColors.tealPrimary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Unit selection
                  Wrap(
                    spacing: 8,
                    children: units.map((u) {
                      final bool isSelected = u == selectedUnit;
                      return ChoiceChip(
                        label: Text(u),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedUnit = u;
                            });
                          }
                        },
                        selectedColor: AppColors.tealLight,
                        backgroundColor: const Color(0xFFF2F6F3),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.tealPrimary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
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
                            final name = nameController.text.trim();
                            final parsed = double.tryParse(amountController.text.trim());
                            if (name.isNotEmpty && parsed != null && parsed > 0) {
                              setState(() {
                                _detectedFoods.add(
                                  DetectedFoodItem(
                                    id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                                    name: name,
                                    amount: parsed,
                                    unit: selectedUnit,
                                  ),
                                );
                              });
                            }
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tealPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeFoodItem(int index) {
    setState(() {
      _detectedFoods.removeAt(index);
    });
  }

  Future<void> _onReviewNutrition() async {
    if (_mealName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a meal name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_detectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one detected food item.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final hasInvalid = _detectedFoods.any((f) => f.amount <= 0);
    if (hasInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food quantities must be greater than zero.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedMealName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => MealNutritionReviewScreen(
          mealName: _mealName.trim(),
          imageBytes: widget.imageBytes,
          imageFile: widget.imageFile,
          detectedFoods: _detectedFoods,
          nutritionEstimate: MealNutritionEstimate.fromIngredients(_detectedFoods),
        ),
      ),
    );

    if (updatedMealName != null && updatedMealName.trim().isNotEmpty && mounted) {
      setState(() {
        _mealName = updatedMealName.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgGradientTop,
            Color(0xFFF7FAF8),
            AppColors.bgGradientBottom,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: Text(
            'Review your meal',
            style: AppTypography.sectionTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable review body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        'Check what we found and adjust the portions.',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Meal Photo and Name Card
                      _buildMealHeaderCard(),

                      const SizedBox(height: 22),

                      // 2. Detected Foods Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detected foods',
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_detectedFoods.length} items',
                            style: AppTypography.subtitle.copyWith(
                              fontSize: 12.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. Detected Foods List
                      _buildDetectedFoodsList(),

                      const SizedBox(height: 12),

                      // 4. Add Missing Food Action
                      Center(
                        child: TextButton.icon(
                          onPressed: _addFoodItem,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Add food item',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.tealPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 5. Portion estimation disclaimer note
                      Center(
                        child: Text(
                          'Portions are estimates. Review them before continuing.',
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Actions: Primary "Review Nutrition" & Secondary "Change photo"
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_detectedFoods.isNotEmpty && _mealName.trim().isNotEmpty)
                            ? _onReviewNutrition
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealPrimary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.tealPrimary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Review Nutrition',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size.fromHeight(38),
                      ),
                      child: const Text(
                        'Change Photo',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Selected Meal Photo
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFEFF3F0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.imageBytes != null
                  ? Image.memory(
                      widget.imageBytes!,
                      fit: BoxFit.cover,
                      width: 82,
                      height: 82,
                    )
                  : const Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 32,
                        color: AppColors.tealAccent,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Meal Name & Edit Affordance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Identified Meal',
                  style: AppTypography.subtitle.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: _editMealName,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _mealName,
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: AppColors.tealPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap meal name to edit',
                  style: AppTypography.subtitle.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedFoodsList() {
    if (_detectedFoods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.info_outline_rounded, size: 28, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                'No items detected',
                style: AppTypography.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "+ Add food item" below to add an ingredient manually.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _detectedFoods.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          color: Color(0xFFF1F4F2),
        ),
        itemBuilder: (context, index) {
          final item = _detectedFoods[index];

          return InkWell(
            onTap: () => _editFoodItem(index),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                children: [
                  // Item-specific food thumbnail
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.imageAsset != null
                          ? Image.asset(
                              item.imageAsset!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.restaurant_rounded,
                                size: 20,
                                color: AppColors.tealAccent,
                              ),
                            )
                          : const Icon(
                              Icons.restaurant_rounded,
                              size: 20,
                              color: AppColors.tealAccent,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Food name and estimated quantity
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.formattedQuantity,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tealPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit affordance
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Edit portion',
                    onPressed: () => _editFoodItem(index),
                  ),

                  // Subtle remove option
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    tooltip: 'Remove',
                    onPressed: () => _removeFoodItem(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
