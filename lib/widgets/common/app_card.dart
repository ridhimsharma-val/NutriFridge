import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Reusable card component for the NutriFridge design system.
/// Features consistent 24px corner radius, delicate hairline borders,
/// and subtle elevation shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.cardWhite,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(18.0),
    this.onTap,
    this.shadows = const [AppColors.softShadow],
    this.clipBehavior = Clip.antiAlias,
  });

  /// Factory for a crisp white card surface
  factory AppCard.white({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18.0),
    VoidCallback? onTap,
    double borderRadius = 24.0,
  }) {
    return AppCard(
      key: key,
      backgroundColor: AppColors.cardWhite,
      borderColor: AppColors.cardBorder,
      padding: padding,
      onTap: onTap,
      borderRadius: borderRadius,
      child: child,
    );
  }

  /// Factory for a warm cream card surface
  factory AppCard.cream({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18.0),
    VoidCallback? onTap,
    double borderRadius = 24.0,
  }) {
    return AppCard(
      key: key,
      backgroundColor: AppColors.warmCream,
      borderColor: AppColors.cardBorder,
      padding: padding,
      onTap: onTap,
      borderRadius: borderRadius,
      child: child,
    );
  }

  /// Factory for a subtle mint tinted card surface
  factory AppCard.mint({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18.0),
    VoidCallback? onTap,
    double borderRadius = 24.0,
  }) {
    return AppCard(
      key: key,
      backgroundColor: AppColors.paleMint,
      borderColor: const Color(0xFFC7E7DA),
      padding: padding,
      onTap: onTap,
      borderRadius: borderRadius,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cardBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.cardBorder,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}
