import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/grocery_item.dart';
import '../../services/grocery/grocery_service.dart';

/// Full interactive Grocery Shopping List screen.
///
/// Features:
/// - Editorial, warm-cream aesthetic matching NutriFridge's design language.
/// - Header with live completed progress bar and counter ("X of Y completed").
/// - Quick Add section with dynamic auto-category detection, quantity stepper, and unit picker.
/// - Duplicate item detection dialog (increase quantity vs keep separate).
/// - Categorized pending list with custom circular checkboxes, strikethrough, edit & delete.
/// - Edit item dialog for name, quantity, unit, and category.
/// - Transfer completed items to Fridge Inventory with configurable expiry dates.
/// - Clear completed items with confirmation dialog.
class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final FocusNode _quantityFocusNode = FocusNode();

  double _quantity = 1.0;
  String _selectedUnit = 'pieces';
  String _selectedCategory = 'Others';
  bool _manualCategoryOverride = false;
  bool _isAdding = false;
  bool _showCompletedSection = true;
  bool _isTransferring = false;
  final Set<String> _togglingIds = {};

  void _decrementQuantity() {
    final current = double.tryParse(_quantityController.text.trim()) ?? _quantity;
    if (current > 1) {
      final updated = (current - 1.0).clamp(0.1, 99999.0);
      setState(() {
        _quantity = updated;
        _quantityController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(1);
      });
    }
  }

  void _incrementQuantity() {
    final current = double.tryParse(_quantityController.text.trim()) ?? _quantity;
    final updated = (current + 1.0).clamp(0.1, 99999.0);
    setState(() {
      _quantity = updated;
      _quantityController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(1);
    });
  }

  void _onQuantityTextChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final parsed = double.tryParse(trimmed);
    if (parsed != null && parsed > 0) {
      _quantity = parsed;
    }
  }

  Future<void> _handleOneTapTransfer(List<GroceryItem> eligibleItems) async {
    if (_isTransferring) return;
    if (eligibleItems.isEmpty) return;

    setState(() => _isTransferring = true);

    try {
      final result = await GroceryService.instance.transferPurchasedToFridge(
        itemsToTransfer: eligibleItems,
        defaultExpiryDays: 7,
      );

      if (!mounted) return;

      if (result.isFullSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('grocery_transfer_success_snackbar'),
            content: Text(
              result.transferredCount == 1
                  ? '1 grocery added to your fridge!'
                  : '${result.transferredCount} groceries added to your fridge!',
            ),
            backgroundColor: AppColors.primaryForest,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.isPartialSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('grocery_transfer_partial_snackbar'),
            content: Text(
              'Added ${result.transferredCount} to fridge. ${result.failedCount} failed.',
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('grocery_transfer_error_snackbar'),
            content: Text('Failed to transfer items to fridge. Please try again.'),
            backgroundColor: Color(0xFFC53929),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  Future<void> _handleTogglePurchased(String itemId) async {
    if (_togglingIds.contains(itemId)) return;
    _togglingIds.add(itemId);

    try {
      final success = await GroceryService.instance.togglePurchased(itemId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update item. Please check your connection.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFC53929),
          ),
        );
      }
    } finally {
      _togglingIds.remove(itemId);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    // Refresh items on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GroceryService.instance.fetchGroceryItems();
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocusNode.dispose();
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final text = _nameController.text.trim();
    if (!_manualCategoryOverride) {
      final autoCat = GroceryCategoryResolver.resolveCategory(text);
      if (autoCat != _selectedCategory) {
        setState(() {
          _selectedCategory = autoCat;
        });
      }
    }
  }

  Future<void> _handleAddItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item name'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rawQty = _quantityController.text.trim();
    final parsedQty = double.tryParse(rawQty);
    if (parsedQty == null || parsedQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity greater than zero'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFC53929),
        ),
      );
      return;
    }
    _quantity = parsedQty;

    if (_isAdding) return;
    setState(() => _isAdding = true);

    try {
      final result = await GroceryService.instance.addWithDuplicateCheck(
        name: name,
        quantity: _quantity,
        unit: _selectedUnit,
        category: _selectedCategory,
      );

      if (!mounted) return;

      if (result.type == GroceryAddResultType.duplicateFound &&
          result.existingDuplicate != null) {
        _showDuplicateDialog(result.existingDuplicate!, name, _quantity, _selectedUnit, _selectedCategory);
      } else if (result.isSuccess) {
        _resetInputForm();
      } else if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: const Color(0xFFC53929),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _resetInputForm() {
    _nameController.clear();
    _quantityController.text = '1';
    setState(() {
      _quantity = 1.0;
      _selectedUnit = 'pieces';
      _selectedCategory = 'Others';
      _manualCategoryOverride = false;
    });
  }

  void _showDuplicateDialog(
    GroceryItem existing,
    String name,
    double qty,
    String unit,
    String category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('grocery_duplicate_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: AppColors.freshGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'Item Already Exists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '"${existing.name}" is already on your list with ${existing.displayQuantity}.\n\n'
          'Would you like to increase its quantity to ${existing.quantity + qty} $unit or add it as a separate item?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          OutlinedButton(
            key: const Key('duplicate_add_separate_btn'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await GroceryService.instance.forceAddItem(
                name: name,
                quantity: qty,
                unit: unit,
                category: category,
              );
              if (mounted) _resetInputForm();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryForest),
            ),
            child: const Text('Add Separate', style: TextStyle(color: AppColors.primaryForest)),
          ),
          ElevatedButton(
            key: const Key('duplicate_increase_qty_btn'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await GroceryService.instance.increaseItemQuantity(existing.id, qty);
              if (mounted) _resetInputForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryForest,
              foregroundColor: Colors.white,
            ),
            child: const Text('Increase Quantity'),
          ),
        ],
      ),
    );
  }

  void _showEditItemSheet(GroceryItem item) {
    final editNameController = TextEditingController(text: item.name);
    final editQtyController = TextEditingController(
      text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
    );
    double editQty = item.quantity;
    String editUnit = item.unit;
    String editCat = item.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Grocery Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.mutedText),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('edit_item_name_input'),
                  controller: editNameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.subtleBorder),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: AppColors.freshGreen, size: 18),
                              onPressed: () {
                                final current = double.tryParse(editQtyController.text.trim()) ?? editQty;
                                if (current > 1) {
                                  final updated = (current - 1).clamp(0.1, 99999.0);
                                  setModalState(() {
                                    editQty = updated;
                                    editQtyController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(1);
                                  });
                                }
                              },
                            ),
                            Expanded(
                              child: TextField(
                                key: const Key('edit_item_qty_input'),
                                controller: editQtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  final p = double.tryParse(val.trim());
                                  if (p != null && p > 0) editQty = p;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: AppColors.freshGreen, size: 18),
                              onPressed: () {
                                final current = double.tryParse(editQtyController.text.trim()) ?? editQty;
                                final updated = (current + 1).clamp(0.1, 99999.0);
                                setModalState(() {
                                  editQty = updated;
                                  editQtyController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(1);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: editUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: GroceryItem.commonUnits.map((u) {
                          return DropdownMenuItem(value: u, child: Text(u));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => editUnit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: editCat,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: GroceryItem.canonicalCategories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => editCat = val);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('edit_item_save_btn'),
                    onPressed: () async {
                      final updatedName = editNameController.text.trim();
                      if (updatedName.isEmpty) return;
                      final finalQty = double.tryParse(editQtyController.text.trim()) ?? editQty;
                      if (finalQty <= 0) return;

                      Navigator.of(sheetContext).pop();
                      await GroceryService.instance.updateItem(
                        item.copyWith(
                          name: updatedName,
                          quantity: finalQty,
                          unit: editUnit,
                          category: editCat,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryForest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmClearCompleted(int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('clear_completed_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Completed Items?'),
        content: Text(
          'Are you sure you want to remove all $count purchased items from your grocery list?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            key: const Key('confirm_clear_completed_btn'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final cleared = await GroceryService.instance.clearCompleted();
              if (mounted && cleared > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleared $cleared completed items'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC53929),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _openTransferToFridgeSheet(List<GroceryItem> completedItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FridgeTransferSheet(completedItems: completedItems),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7EE), // Warm editorial paper cream
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('grocery_back_btn'),
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Grocery List',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          ValueListenableBuilder<List<GroceryItem>>(
            valueListenable: GroceryService.instance.groceryItemsNotifier,
            builder: (context, items, _) {
              final completed = items.where((it) => it.isPurchased).toList();
              if (completed.isEmpty) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('grocery_clear_completed_action_btn'),
                    tooltip: 'Clear completed',
                    icon: const Icon(Icons.cleaning_services_outlined, color: AppColors.mutedText, size: 22),
                    onPressed: () => _confirmClearCompleted(completed.length),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton.icon(
                      key: const Key('grocery_transfer_to_fridge_btn'),
                      onPressed: () => _openTransferToFridgeSheet(completed),
                      icon: const Icon(Icons.kitchen_outlined, size: 16, color: AppColors.primaryForest),
                      label: Text(
                        'Fridge (${completed.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryForest),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: AppColors.primaryForest),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<GroceryItem>>(
          valueListenable: GroceryService.instance.groceryItemsNotifier,
          builder: (context, items, _) {
            final totalCount = items.length;
            final completedCount = items.where((it) => it.isPurchased).length;
            final pendingCount = totalCount - completedCount;
            final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

            return CustomScrollView(
              slivers: [
                // 1. Shopping Progress Header Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildProgressCard(completedCount, totalCount, progress),
                  ),
                ),

                // 2. Quick Add Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _buildQuickAddCard(),
                  ),
                ),

                // 3. List Content or Empty State
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  // Section: To Buy
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 16, color: AppColors.primaryForest),
                          const SizedBox(width: 6),
                          const Text(
                            'To Buy',
                            key: Key('grocery_to_buy_header'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryForest,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neutralTrack,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pendingCount.toString(),
                              key: const Key('grocery_to_buy_count_badge'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // If To Buy has items, render categorized pending list
                  if (pendingCount > 0)
                    ..._buildCategorizedPendingList(items.where((it) => !it.isPurchased).toList())
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6F3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle_outline, size: 16, color: AppColors.freshGreen),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'All items collected! No items remaining in To Buy.',
                                  style: TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Section: Completed
                  if (completedCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: _buildCompletedSection(items.where((it) => it.isPurchased).toList()),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildProgressCard(int completed, int total, double progress) {
    final remaining = total - completed;
    final isAllCompleted = total > 0 && completed == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAllCompleted ? AppColors.freshGreen.withValues(alpha: 0.4) : AppColors.subtleBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Section Title & Percentage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.shopping_bag_outlined, color: AppColors.primaryForest, size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Shopping Progress',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryForest,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAllCompleted ? AppColors.paleMint : AppColors.neutralTrack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  total == 0 ? '0%' : '${(progress * 100).toInt()}%',
                  key: const Key('grocery_percentage_text'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isAllCompleted ? AppColors.primaryForest : AppColors.darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: "X of Y items completed"
          Text(
            total == 0
                ? '0 of 0 items completed'
                : '$completed of $total items completed',
            key: const Key('grocery_progress_text'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Prominent animated horizontal progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return LinearProgressIndicator(
                  key: const Key('grocery_progress_indicator'),
                  value: animatedValue,
                  minHeight: 10,
                  backgroundColor: AppColors.neutralTrack,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAllCompleted ? const Color(0xFF22A06B) : AppColors.primaryForest,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Row 4: Stat Chips: Completed count and Remaining count
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.paleGreenSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 13, color: AppColors.freshGreen),
                    const SizedBox(width: 4),
                    Text(
                      '$completed completed',
                      key: const Key('grocery_completed_count_text'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryForest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending_actions_outlined, size: 13, color: AppColors.mutedText),
                    const SizedBox(width: 4),
                    Text(
                      '$remaining remaining',
                      key: const Key('grocery_remaining_count_text'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 5: Completion Celebration Banner (when all items completed)
          if (isAllCompleted) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('grocery_completion_celebration'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paleMint.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.freshGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.freshGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.task_alt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Shopping list completed!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryForest,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'All items marked as purchased. Ready to transfer to your fridge or clear.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAddCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Item Name Input + Auto-Category Chip
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('grocery_item_name_input'),
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleAddItem(),
                  decoration: InputDecoration(
                    hintText: 'Add an item (e.g. Milk, Apples, Bread)...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF8FAF6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.subtleBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.subtleBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primaryForest, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Quantity Stepper, Unit Selector, Category Pill, and Add Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;

              final qtyStepper = Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.subtleBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('grocery_qty_decrement_btn'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 38),
                      icon: const Icon(Icons.remove, size: 16, color: AppColors.darkText),
                      onPressed: _decrementQuantity,
                    ),
                    SizedBox(
                      width: 50,
                      child: KeyedSubtree(
                        key: const Key('grocery_qty_display'),
                        child: TextField(
                          key: const Key('grocery_qty_input'),
                          controller: _quantityController,
                          focusNode: _quantityFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: _onQuantityTextChanged,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('grocery_qty_increment_btn'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 38),
                      icon: const Icon(Icons.add, size: 16, color: AppColors.darkText),
                      onPressed: _incrementQuantity,
                    ),
                  ],
                ),
              );

              Widget buildUnitSelector({bool isExpanded = false}) {
                return Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.subtleBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('grocery_unit_selector'),
                      value: _selectedUnit,
                      isDense: true,
                      isExpanded: isExpanded,
                      style: const TextStyle(fontSize: 12, color: AppColors.darkText, fontWeight: FontWeight.w600),
                      items: GroceryItem.commonUnits.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(u, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                );
              }

              final categoryPill = PopupMenuButton<String>(
                key: const Key('grocery_category_pill'),
                tooltip: 'Change category',
                initialValue: _selectedCategory,
                onSelected: (cat) {
                  setState(() {
                    _selectedCategory = cat;
                    _manualCategoryOverride = true;
                  });
                },
                itemBuilder: (ctx) => GroceryItem.canonicalCategories.map((c) {
                  return PopupMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                }).toList(),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.paleMint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.freshGreen.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _selectedCategory,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryForest,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primaryForest),
                    ],
                  ),
                ),
              );

              final addButton = SizedBox(
                height: 38,
                child: ElevatedButton(
                  key: const Key('grocery_add_item_btn'),
                  onPressed: _isAdding ? null : _handleAddItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              );

              if (isCompact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        qtyStepper,
                        const SizedBox(width: 8),
                        Expanded(child: buildUnitSelector(isExpanded: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: categoryPill),
                        const SizedBox(width: 8),
                        addButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  qtyStepper,
                  const SizedBox(width: 8),
                  buildUnitSelector(isExpanded: false),
                  const SizedBox(width: 8),
                  Expanded(child: categoryPill),
                  const SizedBox(width: 8),
                  addButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Your shopping list is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add ingredients for your next grocery run or bookmark them directly from recipe cards.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mutedText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorizedPendingList(List<GroceryItem> pendingItems) {
    if (pendingItems.isEmpty) return [];

    // Group items by category preserving canonical category ordering
    final Map<String, List<GroceryItem>> grouped = {};
    for (final cat in GroceryItem.canonicalCategories) {
      final itemsInCat = pendingItems.where((it) => it.category == cat).toList();
      if (itemsInCat.isNotEmpty) {
        grouped[cat] = itemsInCat;
      }
    }

    // Handle any items with custom category outside canonical
    final remainingItems = pendingItems
        .where((it) => !GroceryItem.canonicalCategories.contains(it.category))
        .toList();
    if (remainingItems.isNotEmpty) {
      grouped['Others'] = [...(grouped['Others'] ?? []), ...remainingItems];
    }

    final List<Widget> slivers = [];

    grouped.forEach((category, items) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryForest,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.neutralTrack,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    items.length.toString(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedText),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return _buildGroceryItemCard(item);
              },
              childCount: items.length,
            ),
          ),
        ),
      );
    });

    return slivers;
  }

  Widget _buildGroceryItemCard(GroceryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isPurchased ? Colors.transparent : AppColors.subtleBorder,
        ),
        boxShadow: item.isPurchased
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: _AnimatedGroceryCheckbox(
            checkboxKey: Key('grocery_item_checkbox_${item.id}'),
            isPurchased: item.isPurchased,
            onTap: () => _handleTogglePurchased(item.id),
          ),
          title: Text(
            item.name,
            key: Key('grocery_item_name_${item.id}'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: item.isPurchased ? AppColors.mutedText : AppColors.darkText,
              decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.displayQuantity,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryForest),
                ),
              ),
              if (item.category.isNotEmpty)
                Text(
                  '•  ${item.category}',
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                ),
              if (item.isTransferred)
                Container(
                  key: Key('transferred_badge_${item.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.paleMint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.kitchen, size: 10, color: AppColors.primaryForest),
                      SizedBox(width: 3),
                      Text(
                        'In Fridge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryForest,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('grocery_item_edit_${item.id}'),
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.mutedText),
                onPressed: () => _showEditItemSheet(item),
              ),
              IconButton(
                key: Key('grocery_item_delete_${item.id}'),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC53929)),
                onPressed: () => GroceryService.instance.deleteItem(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedSection(List<GroceryItem> completedItems) {
    final eligible = completedItems.where((it) => it.isPurchased && !it.isTransferred).toList();
    final eligibleCount = eligible.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              key: const Key('grocery_completed_toggle'),
              onTap: () => setState(() => _showCompletedSection = !_showCompletedSection),
              title: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.freshGreen, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Completed',
                    key: Key('grocery_completed_header'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryForest,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.neutralTrack,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      completedItems.length.toString(),
                      key: const Key('grocery_completed_count_badge'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                _showCompletedSection ? Icons.expand_less : Icons.expand_more,
                key: const Key('grocery_completed_expand_icon'),
                color: AppColors.mutedText,
              ),
            ),
          ),
          if (_showCompletedSection) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: completedItems.map((item) => _buildGroceryItemCard(item)).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: KeyedSubtree(
                  key: const Key('grocery_transfer_completed_footer_btn'),
                  child: ElevatedButton.icon(
                    key: const Key('add_purchased_to_fridge_btn'),
                    onPressed: eligibleCount == 0 || _isTransferring
                        ? null
                        : () => _handleOneTapTransfer(eligible),
                    icon: _isTransferring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.kitchen_outlined, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isTransferring
                            ? 'Adding to Fridge...'
                            : 'Add $eligibleCount Purchased ${eligibleCount == 1 ? 'Item' : 'Items'} to Fridge',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryForest,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.neutralTrack,
                      disabledForegroundColor: AppColors.mutedText,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom Sheet for transferring completed grocery items directly into Fridge inventory.
class _FridgeTransferSheet extends StatefulWidget {
  final List<GroceryItem> completedItems;

  const _FridgeTransferSheet({required this.completedItems});

  @override
  State<_FridgeTransferSheet> createState() => _FridgeTransferSheetState();
}

class _FridgeTransferSheetState extends State<_FridgeTransferSheet> {
  late final Set<String> _selectedIds;
  int _selectedExpiryDays = 7;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    final untransferred = widget.completedItems.where((it) => !it.isTransferred).toList();
    _selectedIds = (untransferred.isNotEmpty ? untransferred : widget.completedItems)
        .map((it) => it.id)
        .toSet();
  }

  Future<void> _handleConfirmTransfer() async {
    if (_isTransferring) return;
    final candidates = widget.completedItems
        .where((it) => _selectedIds.contains(it.id))
        .toList();

    if (candidates.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isTransferring = true);

    try {
      final result = await GroceryService.instance.transferPurchasedToFridge(
        itemsToTransfer: candidates,
        defaultExpiryDays: _selectedExpiryDays > 0 ? _selectedExpiryDays : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('grocery_transfer_success_snackbar'),
          content: Text(
            result.transferredCount > 0
                ? (result.transferredCount == 1
                    ? '1 grocery added to your fridge!'
                    : '${result.transferredCount} groceries added to your fridge!')
                : 'Failed to transfer items to fridge.',
          ),
          backgroundColor: result.transferredCount > 0 ? AppColors.primaryForest : const Color(0xFFC53929),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.kitchen_outlined, color: AppColors.primaryForest, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Add Items to Fridge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.mutedText),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select which purchased items to add to your active fridge inventory:',
            style: TextStyle(fontSize: 13, color: AppColors.mutedText),
          ),
          const SizedBox(height: 12),

          // Items selection list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.completedItems.length,
              itemBuilder: (ctx, index) {
                final item = widget.completedItems[index];
                final isSelected = _selectedIds.contains(item.id);
                final fridgeCategory = GroceryCategoryResolver.mapToFridgeCategory(
                  item.category,
                  item.name,
                );

                return Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.freshGreen,
                    value: isSelected,
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${item.displayQuantity}  →  $fridgeCategory',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(item.id);
                        } else {
                          _selectedIds.remove(item.id);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(height: 24),
          const Text(
            'Set Expiry Window:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: [3, 7, 14, 0].map((days) {
              final isSelected = _selectedExpiryDays == days;
              final label = days == 0 ? 'No Expiry' : '$days Days';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppColors.paleMint,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primaryForest : AppColors.mutedText,
                ),
                onSelected: (_) => setState(() => _selectedExpiryDays = days),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('confirm_transfer_to_fridge_btn'),
              onPressed: _isTransferring || _selectedIds.isEmpty ? null : _handleConfirmTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryForest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isTransferring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Add ${_selectedIds.length} Items to Fridge',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tactile, micro-animated circular checkbox for grocery completion.
class _AnimatedGroceryCheckbox extends StatefulWidget {
  final bool isPurchased;
  final VoidCallback onTap;
  final Key? checkboxKey;

  const _AnimatedGroceryCheckbox({
    required this.isPurchased,
    required this.onTap,
    this.checkboxKey,
  });

  @override
  State<_AnimatedGroceryCheckbox> createState() => _AnimatedGroceryCheckboxState();
}

class _AnimatedGroceryCheckboxState extends State<_AnimatedGroceryCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.84).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.84, end: 1.10).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        key: widget.checkboxKey,
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isPurchased ? AppColors.freshGreen : Colors.transparent,
            border: Border.all(
              color: widget.isPurchased ? AppColors.freshGreen : const Color(0xFFB4C8BE),
              width: 1.8,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: widget.isPurchased
                ? const Icon(Icons.check, size: 16, color: Colors.white, key: ValueKey('checked_icon'))
                : const SizedBox.shrink(key: ValueKey('unchecked_icon')),
          ),
        ),
      ),
    );
  }
}
