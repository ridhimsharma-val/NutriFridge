import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../ai_assistant/services/ai_assistant_service.dart';
import '../fridge/models/category_item.dart';
import '../fridge/models/ingredient_addition_data.dart';
import '../fridge/widgets/cinematic_fridge_addition_screen.dart';
import 'widgets/food_scan_preview.dart';

class _ReceiptItem {
  bool isSelected = true;
  final String name;
  final String quantity;
  final String category;
  final int expiryDays;
  final String emoji;

  _ReceiptItem({
    required this.name,
    required this.quantity,
    required this.category,
    required this.expiryDays,
    required this.emoji,
  });
}

/// Grocery list / receipt scanning & item selection screen
class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  String? _previewImage;
  bool _isAnalyzing = false;
  bool _analysisComplete = false;

  late List<_ReceiptItem> _extractedItems;

  @override
  void initState() {
    super.initState();
    _extractedItems = [];
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
          _previewImage = null;
          _analysisComplete = false;
          _extractedItems = [];
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

  Future<void> _analyzeReceipt() async {
    if (_previewImageBytes == null) {
      _showFeedback('Please take or choose a photo of a receipt or grocery list first.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final base64Image = base64Encode(_previewImageBytes!);
      final response = await AiAssistantService.sendRequest(
        message: 'Extract all grocery items, quantities, and units from this receipt image for fridge inventory',
        imageBase64: base64Image,
        mimeType: 'image/jpeg',
        actionHint: 'add_inventory',
      );

      if (!mounted) return;

      final items = response['inventoryItems'];
      final List<_ReceiptItem> parsedItems = [];

      if (items is List && items.isNotEmpty) {
        for (final raw in items) {
          final item = raw as Map<String, dynamic>;
          final name = item['name']?.toString() ?? 'Item';
          final cat = item['category']?.toString() ?? 'Others';
          final qty = item['quantity']?.toString() ?? '1';
          final unit = item['unit']?.toString() ?? 'item';
          final exp = (item['expiryDaysEstimate'] is num)
              ? (item['expiryDaysEstimate'] as num).toInt()
              : 5;
          parsedItems.add(
            _ReceiptItem(
              name: name,
              quantity: '$qty $unit'.trim(),
              category: cat,
              expiryDays: exp,
              emoji: FoodItemAssetRegistry.getEmojiForCategory(cat),
            ),
          );
        }
      }

      setState(() {
        _isAnalyzing = false;
        _analysisComplete = true;
        _extractedItems = parsedItems;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = true;
          _extractedItems = [];
        });
        _showFeedback('Unable to read receipt items. Please try again.');
      }
    }
  }

  void _onAddSelectedToFridge() {
    final selected = _extractedItems.where((it) => it.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item from the receipt'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    for (final item in selected) {
      FridgeCategoryRepository.addItemToCategory(
        item.category,
        CategoryFoodItem(
          id: 'food_rcpt_${DateTime.now().microsecondsSinceEpoch}_${item.name.toLowerCase()}',
          name: item.name,
          quantity: item.quantity,
          expiryDays: item.expiryDays,
          imageAsset:
              FoodItemAssetRegistry.getAssetForItem(item.name, item.category),
          iconEmoji: item.emoji,
        ),
      );
    }

    final addedEntities = selected.map((item) {
      return AddedIngredientItem(
        name: item.name,
        quantityDisplay: item.quantity,
        category: item.category,
        expiryDays: item.expiryDays,
        imageAsset: FoodItemAssetRegistry.getAssetForItem(item.name, item.category),
      );
    }).toList();

    CinematicFridgeAdditionScreen.show(
      context,
      additionData: IngredientAdditionData.multiple(items: addedEntities),
      onDone: () {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.warmCream,
      child: Scaffold(
        backgroundColor: AppColors.warmCream,
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
            _analysisComplete ? 'Receipt Extraction' : 'Grocery / Receipt',
            style: AppTypography.sectionTitle.copyWith(fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _analysisComplete
              ? _buildExtractedItemsList()
              : FoodScanPreview(
                  previewImageAsset: _previewImage,
                  previewImageBytes: _previewImageBytes,
                  modeTitle: 'Receipt / Grocery',
                  promptText: 'Capture grocery receipt or handwritten list',
                  isAnalyzing: _isAnalyzing,
                  analyzeButtonLabel: 'Scan Receipt',
                  onTakePhoto: _onTakePhoto,
                  onChooseGallery: _onChooseGallery,
                  onAnalyze: _analyzeReceipt,
                ),
        ),
      ),
    );
  }

  Widget _buildExtractedItemsList() {
    if (_extractedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 52, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                'Could not read items from this image.',
                textAlign: TextAlign.center,
                style: AppTypography.cardTitle.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                'Ensure the receipt or grocery list is clear, flat, and well lit.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _analysisComplete = false;
                  });
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Try Another Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedCount = _extractedItems.where((it) => it.isSelected).length;

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
                  'Items Found',
                  style: AppTypography.greeting.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedCount of ${_extractedItems.length} selected',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
        ),

        // Items Found List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: _extractedItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _extractedItems[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isSelected
                        ? AppColors.sageAccent.withValues(alpha: 0.4)
                        : AppColors.cardBorder,
                    width: 1.2,
                  ),
                  boxShadow: const [AppColors.cardShadow],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        item.isSelected = !item.isSelected;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
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
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F8F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTypography.cardTitle.copyWith(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantity} • ${item.category}',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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
              );
            },
          ),
        ),

        // Bottom CTA: [ Add Selected to Fridge ]
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
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.forestGreen.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Add Selected to Fridge',
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
}
