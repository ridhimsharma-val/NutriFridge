import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../fridge/models/category_item.dart';
import 'widgets/food_detection_result.dart';
import 'widgets/food_scan_preview.dart';

/// Single food camera scanning & AI detection screen
class SingleFoodScanPage extends StatefulWidget {
  const SingleFoodScanPage({super.key});

  @override
  State<SingleFoodScanPage> createState() => _SingleFoodScanPageState();
}

class _SingleFoodScanPageState extends State<SingleFoodScanPage> {
  String? _previewImage;
  bool _isAnalyzing = false;
  bool _analysisComplete = false;

  void _onTakePhoto() {
    setState(() {
      _previewImage = 'assets/images/categories/dairy_paneer.png';
      _analysisComplete = false;
    });
  }

  void _onChooseGallery() {
    setState(() {
      _previewImage = 'assets/images/categories/dairy_paneer.png';
      _analysisComplete = false;
    });
  }

  Future<void> _analyzeFood() async {
    setState(() {
      _isAnalyzing = true;
    });

    // Simulate AI processing latency
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analysisComplete = true;
      });
    }
  }

  void _onAddToFridge(
    String foodName,
    String category,
    String quantity,
    int expiryDays,
  ) {
    // Add or update in mock FridgeCategoryRepository
    FridgeCategoryRepository.addItemToCategory(
      category,
      CategoryFoodItem(
        id: 'food_${DateTime.now().millisecondsSinceEpoch}',
        name: foodName,
        quantity: quantity,
        expiryDays: expiryDays,
        imageAsset: _previewImage ??
            FoodItemAssetRegistry.getAssetForItem(foodName, category),
        iconEmoji: '🧀',
      ),
    );

    // Provide feedback and return to fridge/main navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $foodName ($quantity) to $category!'),
        backgroundColor: AppColors.tealPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
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
            onPressed: () {
              if (_analysisComplete) {
                setState(() {
                  _analysisComplete = false;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _analysisComplete ? 'Detection Result' : 'Single Food Scan',
            style: AppTypography.sectionTitle.copyWith(fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _analysisComplete
              ? FoodDetectionResult(
                  foodName: 'Paneer',
                  initialCategory: 'Dairy Products',
                  initialQuantity: 250,
                  unit: 'g',
                  stepAmount: 50,
                  expiryDays: 3,
                  imageAsset: _previewImage ?? 'assets/images/categories/dairy_paneer.png',
                  onAddToFridge: _onAddToFridge,
                )
              : FoodScanPreview(
                  previewImageAsset: _previewImage,
                  modeTitle: 'Single Food',
                  promptText: 'Position one food item in the frame',
                  isAnalyzing: _isAnalyzing,
                  analyzeButtonLabel: 'Analyze Food',
                  onTakePhoto: _onTakePhoto,
                  onChooseGallery: _onChooseGallery,
                  onAnalyze: _analyzeFood,
                ),
        ),
      ),
    );
  }
}
