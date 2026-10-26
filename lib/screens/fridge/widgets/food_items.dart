import 'package:flutter/material.dart';

/// Interactive Category Zone wrapper.
/// Provides physical shelf placement, subtle tactile tap feedback (scale down to 0.96),
/// hover highlight, and clean dark muted blue/teal category text (NO background box or pill).
class CategoryZone extends StatefulWidget {
  final String label;
  final Widget content;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const CategoryZone({
    super.key,
    required this.label,
    required this.content,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<CategoryZone> createState() => _CategoryZoneState();
}

class _CategoryZoneState extends State<CategoryZone>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomCenter,
                        child: widget.content,
                      ),
                    ),
                    const SizedBox(height: 3.5),
                    // Clean category label directly under food image (NO box, NO pill, NO background)
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 7.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C485C), // Dark muted blue/teal
                        letterSpacing: 0.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Real Food Category Visual with shelf drop shadow and transparent cutout placement.
class RealFoodCategoryVisual extends StatelessWidget {
  final String imagePath;
  final double height;
  final double? width;
  final BoxFit fit;
  final double shadowWidthFactor;

  const RealFoodCategoryVisual({
    super.key,
    required this.imagePath,
    this.height = 58.0,
    this.width,
    this.fit = BoxFit.contain,
    this.shadowWidthFactor = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Realistic subtle shelf contact grounding shadow
            Positioned(
              bottom: 0,
              child: Container(
                width: (width ?? height * 1.15) * shadowWidthFactor,
                height: 3.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0C1B28).withValues(alpha: 0.22),
                      blurRadius: 5.5,
                      spreadRadius: 1.2,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ),
            // Real Food Cutout Image (Prominent, un-stylized, photographic)
            Image.asset(
              imagePath,
              height: height,
              width: width,
              fit: fit,
              filterQuality: FilterQuality.medium,
            ),
          ],
        ),
      ],
    );
  }
}
