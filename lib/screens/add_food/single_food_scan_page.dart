import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../ai_assistant/services/ai_assistant_service.dart';
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
  Uint8List? _previewImageBytes;
  bool _isAnalyzing = false;
  bool _analysisComplete = false;

  String _detectedFoodName = '';
  String _detectedCategory = 'Others';
  int _detectedQuantity = 1;
  String _detectedUnit = 'piece';
  int _detectedExpiryDays = 5;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await AppImagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (file == null) {
        // User cancelled camera or gallery picker, preserve existing preview
        return;
      }

      final bytes = await file.readAsBytes();

      if (mounted) {
        setState(() {
          _previewImageBytes = bytes;
          _previewImage = null;
          _analysisComplete = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'camera_access_denied') {
          _showFeedback('Camera permission was denied. You can enable it in Settings or choose from Gallery.');
        } else if (e.code == 'photo_access_denied') {
          _showFeedback('Photo gallery permission was denied. You can enable it in Settings.');
        } else {
          _showFeedback('Permission needed to access ${source == ImageSource.camera ? 'camera' : 'photos'}.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showFeedback('Could not select photo. Please try again.');
      }
    }
  }

  void _onTakePhoto() => _pickImage(ImageSource.camera);

  void _onChooseGallery() => _pickImage(ImageSource.gallery);

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _analyzeFood() async {
    if (_previewImageBytes == null) {
      _showFeedback('Please take or choose a photo first.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final base64Image = base64Encode(_previewImageBytes!);
      final response = await AiAssistantService.sendRequest(
        message: 'Identify this food item for fridge inventory',
        imageBase64: base64Image,
        mimeType: 'image/jpeg',
        actionHint: 'add_inventory',
      );

      if (!mounted) return;

      final items = response['inventoryItems'];
      if (items is List && items.isNotEmpty) {
        final item = items.first as Map<String, dynamic>;
        setState(() {
          _detectedFoodName = item['name']?.toString() ?? 'Food Item';
          _detectedCategory = item['category']?.toString() ?? 'Others';
          _detectedQuantity = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;
          _detectedUnit = item['unit']?.toString() ?? 'piece';
          _detectedExpiryDays = (item['expiryDaysEstimate'] is num)
              ? (item['expiryDaysEstimate'] as num).toInt()
              : 5;
          _isAnalyzing = false;
          _analysisComplete = true;
        });
      } else {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = false;
        });
        _showFeedback(
          response['assistantMessage'] as String? ??
              'Could not identify this food item. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = false;
        });
        _showFeedback('Unable to analyze food. Please check connection and try again.');
      }
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
                  foodName: _detectedFoodName,
                  initialCategory: _detectedCategory,
                  initialQuantity: _detectedQuantity,
                  unit: _detectedUnit,
                  stepAmount: (_detectedUnit == 'g' || _detectedUnit == 'ml') ? 50 : 1,
                  expiryDays: _detectedExpiryDays,
                  imageAsset: _previewImage ?? FoodItemAssetRegistry.getAssetForItem(_detectedFoodName, _detectedCategory),
                  onAddToFridge: _onAddToFridge,
                )
              : FoodScanPreview(
                  previewImageAsset: _previewImage,
                  previewImageBytes: _previewImageBytes,
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
