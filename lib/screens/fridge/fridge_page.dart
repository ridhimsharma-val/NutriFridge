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
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header: My Fridge | dynamic items | dynamic expiring soon | action icon
                FridgeHeader(
                  title: 'My Fridge',
                  itemCount: FridgeCategoryRepository.totalFridgeItems,
                  expiringCount: FridgeCategoryRepository.expiringSoonCount,
                  onActionTap: () async {
                    await FridgePreferencesSheet.show(context);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),

            // Main Centralized Appliance Area (Pure refrigerator without instruction text)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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
