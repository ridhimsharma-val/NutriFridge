import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../fridge/models/category_item.dart';
import 'widgets/food_scan_preview.dart';

class _DetectedItemState {
  bool isSelected = true;
  String name;
  int quantity;
  String unit;
  String category;
  int step;
  int expiryDays;
  String emoji;

  _DetectedItemState({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.step,
    required this.expiryDays,
    required this.emoji,
  });
}

/// Multiple foods detection & review screen
class MultipleFoodsPage extends StatefulWidget {
  const MultipleFoodsPage({super.key});

  @override
  State<MultipleFoodsPage> createState() => _MultipleFoodsPageState();
}

class _MultipleFoodsPageState extends State<MultipleFoodsPage> {
  String? _previewImage;
  bool _isAnalyzing = false;
  bool _analysisComplete = false;

  late List<_DetectedItemState> _detectedItems;

  @override
  void initState() {
    super.initState();
    _detectedItems = [
      _DetectedItemState(
        name: 'Paneer',
        quantity: 250,
        unit: 'g',
        category: 'Dairy Products',
        step: 50,
        expiryDays: 3,
        emoji: '🧀',
      ),
      _DetectedItemState(
        name: 'Apple',
        quantity: 3,
        unit: 'pieces',
        category: 'Fruits',
        step: 1,
        expiryDays: 6,
        emoji: '🍎',
      ),
      _DetectedItemState(
        name: 'Carrot',
        quantity: 4,
        unit: 'pieces',
        category: 'Vegetables',
        step: 1,
        expiryDays: 5,
        emoji: '🥕',
      ),
      _DetectedItemState(
        name: 'Milk',
        quantity: 500,
        unit: 'ml',
        category: 'Dairy Products',
        step: 50,
        expiryDays: 2,
        emoji: '🥛',
      ),
    ];
  }

  Uint8List? _previewImageBytes;

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
          _previewImage = 'assets/images/paneer_rice_bowl.jpg';
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

  Future<void> _analyzeFoods() async {
    setState(() {
      _isAnalyzing = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analysisComplete = true;
      });
    }
  }

  void _onAddSelectedToFridge() {
    final selected = _detectedItems.where((it) => it.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one food item'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    for (final item in selected) {
      FridgeCategoryRepository.addItemToCategory(
        item.category,
        CategoryFoodItem(
          id: 'food_${DateTime.now().microsecondsSinceEpoch}_${item.name.toLowerCase()}',
          name: item.name,
          quantity: '${item.quantity} ${item.unit}',
          expiryDays: item.expiryDays,
          imageAsset:
              FoodItemAssetRegistry.getAssetForItem(item.name, item.category),
          iconEmoji: item.emoji,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${selected.length} foods to your fridge!'),
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
            _analysisComplete ? 'Detected Foods' : 'Multiple Foods Scan',
            style: AppTypography.sectionTitle.copyWith(fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _analysisComplete
              ? _buildReviewList()
              : FoodScanPreview(
                  previewImageAsset: _previewImage,
                  previewImageBytes: _previewImageBytes,
                  modeTitle: 'Multiple Foods',
                  promptText: 'Capture multiple groceries in one shot',
                  isAnalyzing: _isAnalyzing,
                  analyzeButtonLabel: 'Analyze Foods',
                  onTakePhoto: _onTakePhoto,
                  onChooseGallery: _onChooseGallery,
                  onAnalyze: _analyzeFoods,
                ),
        ),
      ),
    );
  }

  Widget _buildReviewList() {
    final selectedCount = _detectedItems.where((it) => it.isSelected).length;

    return Column(
      children: [
        // Header summary
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Detected 4 foods',
                  style: AppTypography.greeting.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedCount of 4 selected',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealPrimary,
                ),
              ),
            ],
          ),
        ),

        // Detected Food items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: _detectedItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _detectedItems[index];
              return _buildDetectedItemCard(item);
            },
          ),
        ),

        // Bottom CTA: [ Review & Add ]
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: selectedCount > 0 ? _onAddSelectedToFridge : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealPrimary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.tealPrimary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Review & Add ($selectedCount)',
                      style: AppTypography.cardTitle.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectedItemCard(_DetectedItemState item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isSelected
              ? AppColors.tealAccent.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: const [AppColors.cardShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              // Checkbox
              Checkbox(
                value: item.isSelected,
                activeColor: AppColors.tealPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                onChanged: (val) {
                  setState(() {
                    item.isSelected = val ?? false;
                  });
                },
              ),
              Text(
                item.emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity} ${item.unit} — ${item.category}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity stepper
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    color: AppColors.tealPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: item.quantity > item.step
                        ? () {
                            setState(() {
                              item.quantity -= item.step;
                            });
                          }
                        : null,
                  ),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    color: AppColors.tealPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      setState(() {
                        item.quantity += item.step;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          // Category Selector
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 8, top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: item.category,
                  isDense: true,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: FridgeCategoryRepository.canonicalCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(
                        cat,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        item.category = val;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
