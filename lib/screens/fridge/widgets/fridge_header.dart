import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class FridgeHeader extends StatelessWidget {
  final String title;
  final int itemCount;
  final int? expiringCount;
  final VoidCallback? onBackTap;
  final VoidCallback? onActionTap;
  final VoidCallback? onExpiringTap;
  final bool isSelectionMode;
  final int selectedCount;

  const FridgeHeader({
    super.key,
    this.title = 'My Fridge',
    this.itemCount = 24,
    this.expiringCount = 3,
    this.onBackTap,
    this.onActionTap,
    this.onExpiringTap,
    this.isSelectionMode = false,
    this.selectedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBackTap != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBackTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 1,
                    ),
                    boxShadow: const [AppColors.cardShadow],
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
          // Title & items count pill (scaled down cleanly if space is tight)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.screenHeading.copyWith(
                      fontSize: isSelectionMode ? 20 : 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutralCharcoal,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: selectedCount > 0 ? AppColors.paleMint : AppColors.sageLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedCount > 0
                              ? AppColors.forestGreen.withValues(alpha: 0.35)
                              : AppColors.sageAccent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              color: selectedCount > 0 ? AppColors.forestGreen : AppColors.neutralMedium,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            selectedCount > 0 ? '$selectedCount selected' : '0 selected',
                            style: AppTypography.badgeText.copyWith(
                              color: selectedCount > 0 ? AppColors.forestGreen : AppColors.neutralMedium,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sageLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.sageAccent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: const BoxDecoration(
                              color: AppColors.forestGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            '$itemCount items',
                            style: AppTypography.badgeText.copyWith(
                              color: AppColors.forestGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isSelectionMode && expiringCount != null && expiringCount! > 0) ...[
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        key: const ValueKey('expiring_soon_badge'),
                        onTap: onExpiringTap,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2EB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.coralHighlight.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5.5,
                                height: 5.5,
                                decoration: const BoxDecoration(
                                  color: AppColors.coralHighlight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4.5),
                              Text(
                                '$expiringCount expiring soon',
                                style: AppTypography.badgeText.copyWith(
                                  color: const Color(0xFFC85A32),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right circular action button (Settings / Overflow)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onActionTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1,
                  ),
                  boxShadow: const [AppColors.cardShadow],
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
