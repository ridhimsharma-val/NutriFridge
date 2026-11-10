import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/food_image/food_image_model.dart';
import '../../../services/food_image/food_image_service.dart';

/// Reusable widget for rendering resolved food images with network caching and smooth fallbacks.
class FoodImageView extends StatelessWidget {
  final String name;
  final FoodEntityType type;
  final String? category;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;
  final bool showAttributionPill;

  const FoodImageView({
    super.key,
    required this.name,
    required this.type,
    this.category,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackWidget,
    this.showAttributionPill = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FoodImageService.instance.changeNotifier,
      builder: (context, _) {
        final imageModel = FoodImageService.instance.getImageSync(
          name: name,
          type: type,
          category: category,
        );

        Widget imageWidget;
        if (imageModel.isNetwork) {
          imageWidget = Image.network(
            imageModel.imageUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                fallbackWidget ?? _buildDefaultFallback(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: width,
                height: height,
                color: AppColors.cardBorder.withValues(alpha: 0.3),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          imageWidget = Image.asset(
            imageModel.imageUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                fallbackWidget ?? _buildDefaultFallback(),
          );
        }

        if (borderRadius != null) {
          imageWidget = ClipRRect(
            borderRadius: borderRadius!,
            child: imageWidget,
          );
        }

        if (showAttributionPill && imageModel.hasAttribution) {
          return Stack(
            children: [
              imageWidget,
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    imageModel.attributionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return imageWidget;
      },
    );
  }

  Widget _buildDefaultFallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
