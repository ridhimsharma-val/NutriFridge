import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/nutrition_data.dart';
import '../../../services/recipe/saved_recipes_service.dart';

/// Interactive heart-shaped Save/Favourite toggle button.
///
/// Features a subtle pop/scale bounce animation upon saving,
/// reactive state synchronization via [SavedRecipesService],
/// duplicate prevention, and graceful error handling.
class RecipeSaveButton extends StatefulWidget {
  final RecipeRecommendation recipe;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onToggle;

  const RecipeSaveButton({
    super.key,
    required this.recipe,
    this.size = 22.0,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(8.0),
    this.onToggle,
  });

  @override
  State<RecipeSaveButton> createState() => _RecipeSaveButtonState();
}

class _RecipeSaveButtonState extends State<RecipeSaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    // Springy pop curve: 1.0 -> 1.35 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 45,
      ),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isProcessing) return;
    _isProcessing = true;

    final service = SavedRecipesService.instance;
    final wasSaved = service.isSaved(widget.recipe);

    // Play scale pop animation when saving
    if (!wasSaved) {
      _animController.forward(from: 0.0);
    }

    try {
      final success = await service.toggleSave(widget.recipe);
      if (!mounted) return;

      if (!success && !wasSaved) {
        // Saving failed: reset animation
        _animController.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save recipe to storage.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      } else {
        widget.onToggle?.call();
      }
    } catch (e) {
      if (mounted) {
        _animController.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage error: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeColor ?? const Color(0xFFE53935);
    final inactive = widget.inactiveColor ?? Colors.black54;

    return ValueListenableBuilder<List<RecipeRecommendation>>(
      valueListenable: SavedRecipesService.instance.savedRecipesNotifier,
      builder: (context, _, __) {
        final isSaved = SavedRecipesService.instance.isSaved(widget.recipe);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('recipe_save_btn_${widget.recipe.id.isNotEmpty ? widget.recipe.id : widget.recipe.title}'),
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isSaved ? active : inactive,
                  size: widget.size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
