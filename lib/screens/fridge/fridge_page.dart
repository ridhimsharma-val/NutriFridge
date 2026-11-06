import 'package:flutter/material.dart';
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

        return Scaffold(
          primary: false,
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Header: My Fridge | dynamic items | dynamic expiring soon | preferences control
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

                // 2. Main Centralized Appliance Area (Positioned immediately below header, fitted without scrolling)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
                    child: Center(
                      child: FittedBox(
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
