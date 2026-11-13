import 'package:flutter/material.dart';
import '../../../services/food_image/cooking_cutout_resolver.dart';
import '../../../services/food_image/food_image_service.dart';
import '../models/category_item.dart';

/// Reusable widget for individual ingredient representations across the Cooking Workspace.
///
/// Follows the 3-tier priority:
/// - Priority 1 & 2: Transparent, background-free cutout (PNG/WebP) with natural proportions.
/// - Priority 3: Contained Fridge-photo fallback without pretending it is transparent.
class CookingIngredientCutoutView extends StatelessWidget {
  final CategoryFoodItem item;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CookingIngredientCutoutView({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodImageService.instance.changeNotifier,
      builder: (context, _) {
        final result = CookingCutoutResolver.resolveSync(item);
        final bool isCutout = result.isTransparentCutout;
        final bool isNetwork = result.isNetwork;
        final String path = result.imagePath;

        Widget imageWidget;
        if (isNetwork) {
          imageWidget = Image.network(
            path,
            key: ValueKey(path),
            width: width,
            height: height,
            fit: isCutout ? fit : BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackEmoji(),
          );
        } else {
          imageWidget = Image.asset(
            path,
            key: ValueKey(path),
            width: width,
            height: height,
            fit: isCutout ? fit : BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackEmoji(),
          );
        }

        if (!isCutout) {
          // Priority 3: Contained Fridge photograph fallback
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular((width ?? 32) * 0.28),
            child: imageWidget,
          );
        }

        return imageWidget;
      },
    );
  }

  Widget _buildFallbackEmoji() {
    return Center(
      child: Text(
        item.iconEmoji ?? '🥘',
        style: TextStyle(
          fontSize: (width != null && width! < 32) ? 14 : 20,
        ),
      ),
    );
  }
}
