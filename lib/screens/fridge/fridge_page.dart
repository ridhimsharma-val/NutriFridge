import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'models/category_item.dart';
import 'models/fridge_preferences.dart';
import 'widgets/category_bottom_sheet.dart';
import 'widgets/fridge_header.dart';
import 'widgets/fridge_preferences_sheet.dart';
import 'widgets/top_freezer_refrigerator.dart';

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  // Independent door states: Top Freezer and Lower Refrigerator
  bool _isFreezerOpen = false;
  bool _isFridgeOpen = false;

  void _toggleFreezer() {
    setState(() {
      _isFreezerOpen = !_isFreezerOpen;
    });
  }

  void _toggleFridge() {
    setState(() {
      _isFridgeOpen = !_isFridgeOpen;
    });
  }

  bool _isNavigatingCategory = false;
  String? _highlightedCategory;

  void _onCategoryTap(String categoryLabel) async {
    if (_isNavigatingCategory) return;
    _isNavigatingCategory = true;

    setState(() {
      _highlightedCategory = categoryLabel;
    });

    // Subtle shelf highlight delay (~220ms) before opening sheet
    await Future.delayed(const Duration(milliseconds: 220));

    if (!mounted) {
      _isNavigatingCategory = false;
      return;
    }

    final categoryData =
        FridgeCategoryRepository.getCategoryData(categoryLabel);
    await CategoryBottomSheet.show(
      context: context,
      category: categoryData,
    );
    if (mounted) {
      setState(() {
        _highlightedCategory = null;
        _isNavigatingCategory = false;
      });
    } else {
      _isNavigatingCategory = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FridgeCategoryRepository.notifier,
        FridgePreferencesRepository.notifier,
      ]),
      builder: (context, _) {
        final totalItems = FridgeCategoryRepository.totalFridgeItems;
        final expiringCount = FridgeCategoryRepository.expiringSoonCount;
        final freshCount = (totalItems - expiringCount).clamp(0, totalItems);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Header: My Fridge | dynamic items | dynamic expiring soon | action icon
                FridgeHeader(
                  title: 'My Fridge',
                  itemCount: totalItems,
                  expiringCount: expiringCount,
                  onActionTap: () async {
                    await FridgePreferencesSheet.show(context);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),

                // 2. Freshness & Inventory Summary Strip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: totalItems == 0
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder, width: 1.0),
                            boxShadow: const [AppColors.softShadow],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.paleMint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.kitchen_outlined,
                                  size: 16,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Your fridge is currently empty · Tap doors to explore',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            // Still Fresh Pill
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.cardBorder, width: 1.0),
                                  boxShadow: const [AppColors.softShadow],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.forestGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        'Fresh: $freshCount',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.neutralCharcoal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Eat First Pill
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: expiringCount > 0
                                      ? const Color(0xFFFFF7F2)
                                      : AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: expiringCount > 0
                                        ? AppColors.coralHighlight.withValues(alpha: 0.35)
                                        : AppColors.cardBorder,
                                    width: 1.0,
                                  ),
                                  boxShadow: const [AppColors.softShadow],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: expiringCount > 0
                                            ? AppColors.coralHighlight
                                            : AppColors.sageAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        expiringCount > 0 ? 'Use soon: $expiringCount' : 'All good',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: expiringCount > 0
                                              ? const Color(0xFFC85A32)
                                              : AppColors.textSecondary,
                                        ),
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

                const SizedBox(height: 4),

                // 3. Main Centralized Appliance Area (Pure refrigerator without instruction text)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 80.0),
                      child: Center(
                        child: TopFreezerRefrigerator(
                          isFreezerOpen: _isFreezerOpen,
                          isFridgeOpen: _isFridgeOpen,
                          onFreezerToggle: _toggleFreezer,
                          onFridgeToggle: _toggleFridge,
                          onCategoryTap: _onCategoryTap,
                          preferences: FridgePreferencesRepository.current,
                          highlightedCategory: _highlightedCategory,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
