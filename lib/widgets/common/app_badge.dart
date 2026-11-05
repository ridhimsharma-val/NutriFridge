import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum AppBadgeVariant {
  primary,
  sage,
  coral,
  neutral,
}

/// Reusable pill badge / chip component
class AppBadge extends StatelessWidget {
  final String text;
  final Widget? leading;
  final bool showDot;
  final AppBadgeVariant variant;
  final EdgeInsetsGeometry padding;

  const AppBadge({
    super.key,
    required this.text,
    this.leading,
    this.showDot = false,
    this.variant = AppBadgeVariant.neutral,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;
    Color dot;

    switch (variant) {
      case AppBadgeVariant.primary:
        bg = AppColors.forestGreen.withValues(alpha: 0.10);
        border = AppColors.forestGreen.withValues(alpha: 0.22);
        fg = AppColors.forestGreen;
        dot = AppColors.forestGreen;
        break;
      case AppBadgeVariant.sage:
        bg = AppColors.sageLight;
        border = const Color(0xFFC7E7DA);
        fg = AppColors.forestGreen;
        dot = AppColors.sageAccent;
        break;
      case AppBadgeVariant.coral:
        bg = const Color(0xFFFDECE6);
        border = AppColors.peachBorder;
        fg = AppColors.coralHighlight;
        dot = AppColors.coralHighlight;
        break;
      case AppBadgeVariant.neutral:
        bg = const Color(0xFFF1F5F3);
        border = const Color(0xFFE2EAE5);
        fg = AppColors.textSecondary;
        dot = AppColors.textTertiary;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: AppTypography.badgeText.copyWith(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
