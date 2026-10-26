import 'package:flutter/material.dart';
import 'models/category_item.dart';
import 'widgets/category_bottom_sheet.dart';
import 'widgets/fridge_header.dart';
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


  void _onCategoryTap(String categoryLabel) async {
    final categoryData =
        FridgeCategoryRepository.getCategoryData(categoryLabel);
    await CategoryBottomSheet.show(
      context: context,
      category: categoryData,
      onAddFood: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Add Food to ${categoryData.name} coming soon'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FridgeCategoryRepository.notifier,
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
                  onActionTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fridge settings & preferences'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

            // Main Centralized Appliance Area (Pure refrigerator without instruction text)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Center(
                    child: TopFreezerRefrigerator(
                      isFreezerOpen: _isFreezerOpen,
                      isFridgeOpen: _isFridgeOpen,
                      onFreezerToggle: _toggleFreezer,
                      onFridgeToggle: _toggleFridge,
                      onCategoryTap: _onCategoryTap,
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
