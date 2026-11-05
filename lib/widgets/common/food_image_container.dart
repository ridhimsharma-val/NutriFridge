import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Reusable food image presentation container for NutriFridge.
/// Features rounded corners, subtle bottom scrim gradient for overlay contrast,
/// hero animation support, and image fallback state.
class FoodImageContainer extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double width;
  final double borderRadius;
  final String? heroTag;
  final Widget? badge;
  final Widget? secondaryBadge;
  final BoxFit fit;

  const FoodImageContainer({
    super.key,
    this.imageUrl,
    this.height = 160.0,
    this.width = double.infinity,
    this.borderRadius = 22.0,
    this.heroTag,
    this.badge,
    this.secondaryBadge,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        width: width,
        color: const Color(0xFFFFECE2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The photographic asset
            _buildImage(),

            // Soft bottom scrim gradient for text / badge contrast
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x36000000),
                  ],
                  stops: [0.6, 1.0],
                ),
              ),
            ),

            // Top-left badge (e.g. Meal slot pill)
            if (badge != null)
              Positioned(
                top: 12,
                left: 12,
                child: badge!,
              ),

            // Top-right or bottom badge (e.g. Prep time)
            if (secondaryBadge != null)
              Positioned(
                top: 12,
                right: 12,
                child: secondaryBadge!,
              ),
          ],
        ),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildImage() {
    final url = imageUrl;
    if (url != null && url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
              ),
            ),
          );
        },
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      color: const Color(0xFFFBECE4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 34,
              color: AppColors.peachAccent,
            ),
            const SizedBox(height: 4),
            Text(
              'NutriFridge Kitchen',
              style: AppTypography.badgeText.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
