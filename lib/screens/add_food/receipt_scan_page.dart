import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../fridge/models/category_item.dart';
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
    _extractedItems = [
      _ReceiptItem(
        name: 'Milk',
        quantity: '500 ml',
        category: 'Dairy Products',
        expiryDays: 3,
        emoji: '🥛',
      ),
      _ReceiptItem(
        name: 'Paneer',
        quantity: '250 g',
        category: 'Dairy Products',
        expiryDays: 4,
        emoji: '🧀',
      ),
      _ReceiptItem(
        name: 'Apples',
        quantity: '4 pieces',
        category: 'Fruits',
        expiryDays: 7,
        emoji: '🍎',
      ),
      _ReceiptItem(
        name: 'Carrots',
        quantity: '500 g',
        category: 'Vegetables',
        expiryDays: 6,
        emoji: '🥕',
      ),
      _ReceiptItem(
        name: 'Bread',
        quantity: '1 pack',
        category: 'Packaged Food',
        expiryDays: 4,
        emoji: '🍞',
      ),
    ];
  }

  void _onTakePhoto() {
    setState(() {
      _previewImage = 'assets/categories/raw/UI 1.jpg';
      _analysisComplete = false;
    });
  }

  void _onChooseGallery() {
    setState(() {
      _previewImage = 'assets/categories/raw/UI 1.jpg';
      _analysisComplete = false;
    });
  }

  Future<void> _analyzeReceipt() async {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${selected.length} items to your fridge!'),
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
                  color: AppColors.tealPrimary,
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
                        ? AppColors.tealAccent.withValues(alpha: 0.4)
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
