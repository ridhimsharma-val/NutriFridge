import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'models/category_item.dart';
import 'models/fridge_preferences.dart';
import 'services/cooking_basket_service.dart';
import 'widgets/category_bottom_sheet.dart';
import 'widgets/cooking_basket_panel.dart';
import 'widgets/expiring_soon_bottom_sheet.dart';
import 'widgets/fridge_header.dart';
import 'widgets/fridge_preferences_sheet.dart';
import 'widgets/top_freezer_refrigerator.dart';

class FridgePage extends StatefulWidget {
  final bool isSelectionMode;

  const FridgePage({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  // Independent door states: Top Freezer and Lower Refrigerator.
  // In selection mode ("Use My Ingredients"), doors default to open immediately
  // so category shelves and inventory are instantly visible and accessible.
  late bool _isFreezerOpen;
  late bool _isFridgeOpen;

  @override
  void initState() {
    super.initState();
    _isFreezerOpen = widget.isSelectionMode;
    _isFridgeOpen = widget.isSelectionMode;
  }

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
      isSelectionMode: widget.isSelectionMode,
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

  void _openExpiringSoon() async {
    await ExpiringSoonBottomSheet.show(context: context);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FridgeCategoryRepository.notifier,
        FridgePreferencesRepository.notifier,
        CookingBasketService.selectedItemsNotifier,
      ]),
      builder: (context, _) {
        final totalItems = FridgeCategoryRepository.totalFridgeItems;
        final expiringCount = FridgeCategoryRepository.expiringSoonCount;
        final selectedCount = CookingBasketService.count;

        return Scaffold(
          primary: false,
          resizeToAvoidBottomInset: widget.isSelectionMode,
          backgroundColor: Colors.transparent,
          bottomNavigationBar: widget.isSelectionMode
              ? const CookingBasketPanel()
              : null,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Header: My Fridge / Select Ingredients | dynamic items | dynamic expiring soon | preferences control
                FridgeHeader(
                  title: widget.isSelectionMode ? 'Select Ingredients' : 'My Fridge',
                  itemCount: totalItems,
                  expiringCount: expiringCount,
                  isSelectionMode: widget.isSelectionMode,
                  selectedCount: selectedCount,
                  onBackTap: widget.isSelectionMode
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  onExpiringTap: _openExpiringSoon,
                  onActionTap: () async {
                    await FridgePreferencesSheet.show(context);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),

                if (FridgeCategoryRepository.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B7E58)),
                  ),

                if (FridgeCategoryRepository.loadError != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBEBEA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF09995)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Color(0xFFC53929)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            FridgeCategoryRepository.loadError!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFC53929)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => FridgeCategoryRepository.loadFromSupabase(force: true),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC53929))),
                        ),
                      ],
                    ),
                  ),

                // 2. Main Centralized Appliance Area (Positioned immediately below header, fitted without scrolling)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 292.0,
                              height: 588.0,
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
                          if (FridgeCategoryRepository.isLoading && totalItems == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [AppColors.softShadow],
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Loading your fridge...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutralCharcoal,
                                    ),
                                  ),
                                ],
                              ),
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
      },
    );
  }
}
