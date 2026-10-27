import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/user_profile_data.dart';

/// Modal bottom sheet popup for editing Dietary Restrictions.
/// Operates on draft state so changes are only committed when Save is tapped.
class DietaryRestrictionsPopup extends StatefulWidget {
  final UserProfileData profile;
  final ValueChanged<UserProfileData> onSave;

  const DietaryRestrictionsPopup({
    super.key,
    required this.profile,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfileData profile,
    required ValueChanged<UserProfileData> onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DietaryRestrictionsPopup(
        profile: profile,
        onSave: onSave,
      ),
    );
  }

  @override
  State<DietaryRestrictionsPopup> createState() =>
      _DietaryRestrictionsPopupState();
}

class _DietaryRestrictionsPopupState extends State<DietaryRestrictionsPopup> {
  late final Set<String> _draftAllergies;
  late final Set<String> _draftAvoided;
  late final List<String> _draftCustom;
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draftAllergies = Set<String>.from(widget.profile.allergies);
    _draftAvoided = Set<String>.from(widget.profile.avoidedFoods);
    _draftCustom = List<String>.from(widget.profile.customRestrictions);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggleAllergy(String allergy) {
    setState(() {
      if (_draftAllergies.contains(allergy)) {
        _draftAllergies.remove(allergy);
      } else {
        _draftAllergies.add(allergy);
      }
    });
  }

  void _toggleAvoided(String food) {
    setState(() {
      if (_draftAvoided.contains(food)) {
        _draftAvoided.remove(food);
      } else {
        _draftAvoided.add(food);
      }
    });
  }

  void _addCustomRestriction() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;

    if (!_draftCustom.contains(text)) {
      setState(() {
        _draftCustom.add(text);
      });
    }
    _customController.clear();
  }

  void _removeCustomRestriction(String item) {
    setState(() {
      _draftCustom.remove(item);
    });
  }

  void _handleSave() {
    final updated = widget.profile.copyWith(
      allergies: _draftAllergies,
      avoidedFoods: _draftAvoided,
      customRestrictions: _draftCustom,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Drag Handle & Title Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE4DF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Dietary restrictions',
                        style: AppTypography.greeting.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFF0F4F2), height: 1),

          // 2. Scrollable Dietary Restrictions Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A. Food Allergies
                  const Text(
                    'Food allergies',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Strict ingredient exclusions for recipes and meal plans',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfileData.commonAllergies.map((allergy) {
                      final isSelected = _draftAllergies.contains(allergy);
                      return _buildTagChip(
                        label: allergy,
                        isSelected: isSelected,
                        selectedBgColor: const Color(0xFFFFF2EB),
                        selectedBorderColor: AppColors.peachPrimary,
                        selectedTextColor: const Color(0xFFD34524),
                        onTap: () => _toggleAllergy(allergy),
                      );
                    }).toList(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(color: Color(0xFFF0F4F2), height: 1),
                  ),

                  // B. Foods They Avoid
                  const Text(
                    'Foods you avoid',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Personal dietary preferences and lifestyle choices',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfileData.commonAvoidedFoods.map((food) {
                      final isSelected = _draftAvoided.contains(food);
                      return _buildTagChip(
                        label: food,
                        isSelected: isSelected,
                        selectedBgColor: const Color(0xFFE8F5F0),
                        selectedBorderColor: AppColors.tealPrimary,
                        selectedTextColor: AppColors.tealPrimary,
                        onTap: () => _toggleAvoided(food),
                      );
                    }).toList(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(color: Color(0xFFF0F4F2), height: 1),
                  ),

                  // C. Custom Dietary Restrictions
                  const Text(
                    'Other restrictions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Add custom ingredients or specific items you do not eat',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Custom entries chips
                  if (_draftCustom.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _draftCustom.map((item) {
                        return Container(
                          padding: const EdgeInsets.only(
                            left: 11,
                            right: 6,
                            top: 5,
                            bottom: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF6F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.tealPrimary.withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tealPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeCustomRestriction(item),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Input row for adding custom item
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Cilantro, Bell peppers',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7FAF8),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFDFE7E2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFDFE7E2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.tealPrimary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _addCustomRestriction(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _addCustomRestriction,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tealPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Factual Non-Medical Disclaimer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBF9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFECEFEA),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'NutriFridge dietary settings are for personal tracking guidance only and do not guarantee allergen safety. Always check package ingredient labels.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: Color(0xFFF0F4F2), height: 1),

          // 3. Bottom Action Buttons (Cancel & Save)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFDFE7E2)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip({
    required String label,
    required bool isSelected,
    required Color selectedBgColor,
    required Color selectedBorderColor,
    required Color selectedTextColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBgColor : const Color(0xFFF6FAF7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? selectedBorderColor : const Color(0xFFDFE7E2),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? selectedTextColor : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
