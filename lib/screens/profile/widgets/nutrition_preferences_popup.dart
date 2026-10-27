import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/user_profile_data.dart';

/// Modal bottom sheet popup for editing Nutrition Preferences.
/// Operates on draft state so changes are only committed when Save is tapped.
class NutritionPreferencesPopup extends StatefulWidget {
  final UserProfileData profile;
  final ValueChanged<UserProfileData> onSave;

  const NutritionPreferencesPopup({
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
      builder: (context) => NutritionPreferencesPopup(
        profile: profile,
        onSave: onSave,
      ),
    );
  }

  @override
  State<NutritionPreferencesPopup> createState() =>
      _NutritionPreferencesPopupState();
}

class _NutritionPreferencesPopupState extends State<NutritionPreferencesPopup> {
  late String? _draftDietary;
  late String? _draftGoal;
  late final TextEditingController _calorieController;
  String? _calorieError;

  @override
  void initState() {
    super.initState();
    _draftDietary = widget.profile.dietaryPreference;
    _draftGoal = widget.profile.nutritionGoal;
    _calorieController = TextEditingController(
      text: widget.profile.dailyCalorieTarget != null
          ? widget.profile.dailyCalorieTarget.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _calorieController.dispose();
    super.dispose();
  }

  void _onToggleDietary(String opt) {
    setState(() {
      if (_draftDietary == opt) {
        _draftDietary = null; // Toggle off / leave unset
      } else {
        _draftDietary = opt;
      }
    });
  }

  void _onToggleGoal(String goal) {
    setState(() {
      if (_draftGoal == goal) {
        _draftGoal = null; // Toggle off / leave unset
      } else {
        _draftGoal = goal;
      }
    });
  }

  void _handleSave() {
    final text = _calorieController.text.trim();
    int? parsedCalorie;

    if (text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed == null || parsed <= 0 || parsed > 9999) {
        setState(() {
          _calorieError = 'Enter a valid target (1 - 9999 kcal)';
        });
        return;
      }
      parsedCalorie = parsed;
    }

    final updated = widget.profile.copyWith(
      dietaryPreference: _draftDietary,
      clearDietaryPreference: _draftDietary == null,
      nutritionGoal: _draftGoal,
      clearNutritionGoal: _draftGoal == null,
      dailyCalorieTarget: parsedCalorie,
      clearCalorieTarget: parsedCalorie == null,
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
                        'Nutrition preferences',
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

          // 2. Scrollable Preference Controls
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A. Dietary Preference
                  const Text(
                    'Dietary preference',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Optional • Tap an option to select or clear',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfileData.dietaryOptions.map((opt) {
                      final isSelected = _draftDietary == opt;
                      return _buildSelectableChip(
                        label: opt,
                        isSelected: isSelected,
                        onTap: () => _onToggleDietary(opt),
                      );
                    }).toList(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(color: Color(0xFFF0F4F2), height: 1),
                  ),

                  // B. Nutrition Goal
                  const Text(
                    'Nutrition goal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Optional • Tap to focus recommendation priorities',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfileData.nutritionGoals.map((goal) {
                      final isSelected = _draftGoal == goal;
                      return _buildSelectableChip(
                        label: goal,
                        isSelected: isSelected,
                        onTap: () => _onToggleGoal(goal),
                      );
                    }).toList(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(color: Color(0xFFF0F4F2), height: 1),
                  ),

                  // C. Daily Calorie Target
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daily calorie target',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Optional baseline daily target',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            if (_calorieError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _calorieError!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD34524),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Numeric Input Field
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _calorieController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealPrimary,
                          ),
                          decoration: InputDecoration(
                            suffixText: ' kcal',
                            suffixStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            hintText: 'None',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7FAF8),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
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
                          onChanged: (_) {
                            if (_calorieError != null) {
                              setState(() {
                                _calorieError = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
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

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
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
            color: isSelected ? AppColors.tealPrimary : const Color(0xFFF6FAF7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.tealPrimary : const Color(0xFFDFE7E2),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
