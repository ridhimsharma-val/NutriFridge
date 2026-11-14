import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/grocery_item.dart';
import '../../../services/grocery/grocery_service.dart';
import '../../grocery/grocery_list_screen.dart';

/// A physical-looking paper sticky note attached to the refrigerator surface.
///
/// Features:
/// - Warm paper texture and color with subtle drop shadow and curled bottom corner.
/// - Dark green decorative circular magnet at the top.
/// - ~2.5 degrees of natural rotation.
/// - Live preview of pending grocery shopping items.
/// - Morphing Hero transition expanding into the full [GroceryListScreen].
class FridgeStickyNote extends StatefulWidget {
  final VoidCallback? onNoteTap;

  const FridgeStickyNote({
    super.key,
    this.onNoteTap,
  });

  @override
  State<FridgeStickyNote> createState() => _FridgeStickyNoteState();
}

class _FridgeStickyNoteState extends State<FridgeStickyNote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    GroceryService.instance.init();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _pressController.forward();
    await _pressController.reverse();

    if (!mounted) return;
    widget.onNoteTap?.call();

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 440),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const GroceryListScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ValueListenableBuilder<List<GroceryItem>>(
        valueListenable: GroceryService.instance.groceryItemsNotifier,
        builder: (context, items, _) {
          final pending = items.where((it) => !it.isPurchased).toList();
          final pendingCount = pending.length;

          return Transform.rotate(
            angle: 0.044, // ~2.5 degrees natural clockwise tilt
            alignment: Alignment.topCenter,
            child: GestureDetector(
              key: const ValueKey('fridge_sticky_note_btn'),
              onTap: _handleTap,
              child: SizedBox(
                width: 96.0,
                height: 104.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // =========================================================
                    // 1. PAPER NOTE BODY & SOFT REALISTIC SHADOW
                    // =========================================================
                    Positioned(
                      top: 7.0,
                      left: 2.0,
                      right: 2.0,
                      bottom: 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF9E3), // Warm yellow/cream paper
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3.0),
                            topRight: Radius.circular(3.0),
                            bottomLeft: Radius.circular(3.0),
                            bottomRight: Radius.circular(10.0), // Curled corner hint
                          ),
                          boxShadow: [
                            // Ambient paper drop shadow
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 8.0,
                              offset: const Offset(3.0, 5.0),
                            ),
                            // Paper thickness rim
                            BoxShadow(
                              color: const Color(0xFFE6D6A2).withValues(alpha: 0.45),
                              blurRadius: 1.0,
                              offset: const Offset(0.0, 1.0),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Subtle Paper Texture / Faint Lines
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _StickyNoteTexturePainter(),
                              ),
                            ),

                            // Note Content
                            Padding(
                              padding: const EdgeInsets.fromLTRB(7.0, 10.0, 6.0, 6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header Row: "Grocery List" & optional badge
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Grocery List',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E4620), // Dark green editorial ink
                                            letterSpacing: -0.2,
                                            height: 1.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (pendingCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4.0, vertical: 1.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A7C59).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6.0),
                                          ),
                                          child: Text(
                                            '$pendingCount',
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E4620),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 4.0),

                                  // Preview Items or Empty Prompt
                                  if (pending.isNotEmpty) ...[
                                    for (int i = 0; i < math.min(3, pending.length); i++)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 3.0,
                                              height: 3.0,
                                              margin: const EdgeInsets.only(right: 3.5),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4A7C59),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                pending[i].name,
                                                style: const TextStyle(
                                                  fontSize: 9.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF333333),
                                                  height: 1.15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (pending.length > 3)
                                      Text(
                                        '+${pending.length - 3} more',
                                        style: TextStyle(
                                          fontSize: 8.0,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF4A7C59).withValues(alpha: 0.85),
                                        ),
                                      ),
                                  ] else ...[
                                    const Spacer(),
                                    const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_note_rounded,
                                            size: 16.0,
                                            color: Color(0xFF5B7E58),
                                          ),
                                          SizedBox(height: 1.0),
                                          Text(
                                            'Tap to add items',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 8.2,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF6B6858),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                ],
                              ),
                            ),

                            // Curled Bottom-Right Corner Flap
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CustomPaint(
                                size: const Size(11.0, 11.0),
                                painter: _CurledCornerPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =========================================================
                    // 2. REALISTIC SAGE-GREEN CIRCULAR FRIDGE MAGNET
                    // =========================================================
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 14.0,
                        height: 14.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2C5E3B), // Forest-sage green
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 3.5,
                              offset: const Offset(0.5, 2.0),
                            ),
                          ],
                        ),
                        child: Align(
                          alignment: const Alignment(-0.35, -0.35),
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints subtle paper lines and texture onto the sticky note canvas.
class _StickyNoteTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFEBDDAE).withValues(alpha: 0.4)
      ..strokeWidth = 0.6;

    // Faint horizontal ruled guidelines
    for (double y = 28.0; y < size.height - 10.0; y += 14.0) {
      canvas.drawLine(Offset(6.0, y), Offset(size.width - 6.0, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints a small 3D folded/curled paper illusion at the bottom-right corner.
class _CurledCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, shadowPaint);

    final foldPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 2.5, size.height - 2.5)
      ..close();

    final flapPaint = Paint()
      ..color = const Color(0xFFF3E7BE)
      ..style = PaintingStyle.fill;

    canvas.drawPath(foldPath, flapPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
