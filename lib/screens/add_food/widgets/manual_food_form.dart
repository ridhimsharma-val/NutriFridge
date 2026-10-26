import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../fridge/models/category_item.dart';

/// Reusable form component for manual food entry
class ManualFoodForm extends StatefulWidget {
  final void Function({
    required String category,
    required String foodName,
    required String quantity,
    required int expiryDays,
  }) onSubmit;

  const ManualFoodForm({
    super.key,
    required this.onSubmit,
  });

  @override
  State<ManualFoodForm> createState() => _ManualFoodFormState();
}

class _ManualFoodFormState extends State<ManualFoodForm> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCategory = 'Dairy Products';
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String _selectedUnit = 'pieces';
  DateTime? _selectedExpiryDate;

  static const List<String> _units = [
    'g',
    'kg',
    'ml',
    'L',
    'pieces',
    'pack',
    'bottle',
    'box',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? now.add(const Duration(days: 5)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.tealPrimary,
              onPrimary: Colors.white,
              surface: AppColors.cardWhite,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final qty = _quantityController.text.trim();
      final category = _selectedCategory ?? 'Others';
      final quantityString = '$qty $_selectedUnit';

      int expiryDays = 5;
      if (_selectedExpiryDate != null) {
        final diff = _selectedExpiryDate!.difference(DateTime.now()).inDays;
        expiryDays = diff < 0 ? 0 : diff + 1;
      }

      widget.onSubmit(
        category: category,
        foodName: name,
        quantity: quantityString,
        expiryDays: expiryDays,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Category Field
          _buildFieldLabel('Category', isRequired: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
              boxShadow: const [AppColors.cardShadow],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.tealPrimary,
                ),
                dropdownColor: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                items: FridgeCategoryRepository.canonicalCategories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(
                      cat,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Food Name Field
          _buildFieldLabel('Food Name', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: AppTypography.cardTitle.copyWith(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: _inputDecoration(
              hint: 'e.g., Greek Yogurt, Strawberries, Paneer',
              prefixIcon: Icons.restaurant_menu_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Food name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // 3. Quantity & Unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity Numeric Input
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Quantity', isRequired: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _inputDecoration(
                        hint: 'e.g., 250',
                        prefixIcon: Icons.scale_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter quantity';
                        }
                        final num = double.tryParse(value.trim());
                        if (num == null || num <= 0) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Unit Dropdown
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Unit', isRequired: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder, width: 1.2),
                        boxShadow: const [AppColors.cardShadow],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.tealPrimary,
                          ),
                          dropdownColor: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          items: _units.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(
                                unit,
                                style: AppTypography.cardTitle.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Select unit';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedUnit = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Expiry Date (Optional)
          _buildFieldLabel('Expiry Date', isRequired: false),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickExpiryDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
                boxShadow: const [AppColors.cardShadow],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: AppColors.tealPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedExpiryDate == null
                          ? 'Optional — tap to set expiry date'
                          : '${_selectedExpiryDate!.day}/${_selectedExpiryDate!.month}/${_selectedExpiryDate!.year} (${_formatDaysLeft()} days left)',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        color: _selectedExpiryDate == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        fontWeight: _selectedExpiryDate == null
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_selectedExpiryDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedExpiryDate = null;
                        });
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 5. Primary CTA: [ Add to Fridge ]
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submit,
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
                children: [
                  const Icon(Icons.check_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add to Fridge',
                    style: AppTypography.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _formatDaysLeft() {
    if (_selectedExpiryDate == null) return 0;
    final diff = _selectedExpiryDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  Widget _buildFieldLabel(String label, {required bool isRequired}) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.cardTitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(0xFFE11D48),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(
            ' (Optional)',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.cardWhite,
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        fontSize: 14,
        color: AppColors.textTertiary,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: AppColors.tealPrimary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.tealAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFFDC2626),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
