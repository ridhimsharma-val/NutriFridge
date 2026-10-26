import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
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
  Uint8List? _previewImageBytes;
  bool _isAnalyzing = false;
  bool _analysisComplete = false;

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
          _previewImage = 'assets/images/categories/dairy_paneer.png';
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
