import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main_navigation_shell.dart';
import 'widgets/floating_ingredients_widget.dart';
import 'widgets/freshness_ring_painter.dart';
import 'widgets/fridge_cabinet_widget.dart';
import 'widgets/fridge_door_widget.dart';
import 'widgets/nutrifridge_brand_reveal.dart';

/// The official "Magic Fridge" startup splash animation for NutriFridge.
///
/// Master sequence:
/// - Scene 1 (0.00–0.18): Refrigerator arrives with soft spring bounce. Door completely closed.
/// - Scene 2 (0.18–0.28): Magical in-place door dissolve (1.0 -> 0.0) revealing illuminated shelves.
/// - Scene 3 (0.28–0.54): 6 fresh ingredients emerge from shelves with smooth staggered arcs.
/// - Scene 4a (0.54–0.68): Ingredients gather into circular orbit as freshness ring draws 360°.
/// - Scene 4b (0.68–0.82): The formed ring & ingredients rotate dynamically in an orbital swirl,
///   gently contracting inward and leading directly into the centered wordmark logo.
/// - Scene 5 (0.82–0.94): Centered NutriFridge brand logo enters with gentle upward motion.
/// - Scene 6 (0.94–1.00): Stable logo hold with seamless transition to dashboard.
class MagicFridgeSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const MagicFridgeSplashScreen({super.key, this.onComplete});

  @override
  State<MagicFridgeSplashScreen> createState() => _MagicFridgeSplashScreenState();
}

class _MagicFridgeSplashScreenState extends State<MagicFridgeSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToDashboard();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigationShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4), // Fresh soft sage background
      body: Center(
        child: ConstrainedBox(
          // Mobile container: full edge-to-edge on phones, capped at 430 on wide screens
          constraints: const BoxConstraints(maxWidth: 430),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Full-screen active splash animation canvas
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return _buildSceneCanvas(context, constraints);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSceneCanvas(BuildContext context, BoxConstraints constraints) {
    final double t = _controller.value; // Master timeline progress 0.0 to 1.0

    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    final centerOffset = Offset(screenWidth / 2, screenHeight / 2 - 14);

    // Responsive fridge dimensions with balanced negative space
    final fridgeWidth = (screenWidth * 0.54).clamp(195.0, 275.0);
    final fridgeHeight = fridgeWidth * 1.48;

    // Timeline variables
    double fridgeY = 0.0;
    double fridgeScale = 1.0;
    double fridgeOpacity = 1.0;
    double shadowScale = 1.0;
    double shadowOpacity = 0.25;
    double doorOpacity = 1.0; // 1.0 initially closed
    double interiorGlow = 0.0;
    double freshnessRingProgress = 0.0;
    double freshnessRingOpacity = 0.0;
    double ringRotation = 0.0;
    double ringContract = 0.0;
    double brandProgress = 0.0;

    // Scene 1: Fridge Arrival & Settling Bounce (0.00–0.18)
    if (t < 0.18) {
      final p = (t / 0.18).clamp(0.0, 1.0);
      final bounceCurve = Curves.easeOutBack.transform(p);
      fridgeY = 95.0 * (1.0 - bounceCurve);
      fridgeScale = 0.86 + 0.14 * bounceCurve;
      shadowScale = 0.45 + 0.55 * bounceCurve;
      shadowOpacity = 0.04 + 0.22 * bounceCurve;
      doorOpacity = 1.0; // Door remains completely closed
      interiorGlow = 0.0;
    }
    // Scene 2: Magical In-Place Door Dissolve (0.18–0.28, ~440ms)
    else if (t < 0.28) {
      final p = ((t - 0.18) / (0.28 - 0.18)).clamp(0.0, 1.0);
      fridgeY = 0.0;
      fridgeScale = 1.0;
      shadowScale = 1.0;
      shadowOpacity = 0.26;

      doorOpacity = (1.0 - Curves.easeInOut.transform(p)).clamp(0.0, 1.0);
      interiorGlow = Curves.easeIn.transform(p);
    }
    // Scene 3: Ingredients Emerge from Shelves (0.28–0.54)
    else if (t < 0.54) {
      fridgeY = 0.0;
      fridgeScale = 1.0;
      shadowScale = 1.0;
      shadowOpacity = 0.26;
      doorOpacity = 0.0;
      interiorGlow = 1.0;
      freshnessRingOpacity = 0.0;
    }
    // Scene 4a: Ingredients Orbit & Ring Draws (0.54–0.68)
    else if (t < 0.68) {
      final p = ((t - 0.54) / (0.68 - 0.54)).clamp(0.0, 1.0);
      fridgeY = 0.0;
      fridgeScale = 1.0;
      shadowScale = 1.0;
      shadowOpacity = 0.26;
      doorOpacity = 0.0;
      interiorGlow = 1.0;

      freshnessRingProgress = Curves.easeInOutCubic.transform(p);
      freshnessRingOpacity = Curves.easeIn.transform(p);
      ringRotation = 0.0;
      ringContract = 0.0;
    }
    // Scene 4b: Ring & Ingredients Rotate in Orbital Swirl, Leading to Wordmark (0.68–0.82)
    else if (t < 0.82) {
      final p = ((t - 0.68) / (0.82 - 0.68)).clamp(0.0, 1.0);
      doorOpacity = 0.0;
      interiorGlow = 1.0;

      freshnessRingProgress = 1.0;
      ringRotation = Curves.easeInOutCubic.transform(p) * (1.85 * math.pi);

      if (p >= 0.50) {
        final contractProg = (p - 0.50) / 0.50;
        ringContract = Curves.easeIn.transform(contractProg);
        final fadeOut = (1.0 - contractProg).clamp(0.0, 1.0);

        freshnessRingOpacity = fadeOut;
        fridgeOpacity = fadeOut;
        shadowOpacity = 0.26 * fadeOut;
        fridgeScale = 1.0 - 0.08 * contractProg;
      } else {
        ringContract = 0.0;
        freshnessRingOpacity = 1.0;
        fridgeOpacity = 1.0;
        shadowOpacity = 0.26;
        fridgeScale = 1.0;
      }
      fridgeY = 0.0;
      shadowScale = 1.0;
    }
    // Scene 5: Centered NutriFridge Logo Reveal & Zoom out to Top Icon (0.80–0.94)
    else if (t < 0.94) {
      final p = ((t - 0.80) / (0.94 - 0.80)).clamp(0.0, 1.0);
      fridgeOpacity = 0.0;
      shadowOpacity = 0.0;
      doorOpacity = 0.0;
      freshnessRingOpacity = 0.0;

      brandProgress = p;
    }
    // Scene 6: Stable Logo Hold & Destination Transition (0.94–1.00)
    else {
      fridgeOpacity = 0.0;
      shadowOpacity = 0.0;
      doorOpacity = 0.0;
      freshnessRingOpacity = 0.0;
      brandProgress = 1.0; // Clean, stable hold
    }

    final fridgeLeft = centerOffset.dx - fridgeWidth / 2;
    final fridgeTop = centerOffset.dy - fridgeHeight / 2 + fridgeY;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Soft Warm Cream / Sage Background
        Container(color: const Color(0xFFF4F7F4)),

        // 2. Soft Contact Ground Shadow underneath Fridge
        if (shadowOpacity > 0.01)
          Positioned(
            left: centerOffset.dx - (fridgeWidth * 0.65 * shadowScale),
            top: centerOffset.dy + fridgeHeight / 2 - 8 + fridgeY,
            width: fridgeWidth * 1.30 * shadowScale,
            height: 26 * shadowScale,
            child: Opacity(
              opacity: shadowOpacity.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(
                      fridgeWidth * 1.30 * shadowScale,
                      26 * shadowScale,
                    ),
                  ),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2E7D32).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 3. Refrigerator Cabinet Body (With shelves & interior glow)
        if (fridgeOpacity > 0.01)
          Positioned(
            left: fridgeLeft,
            top: fridgeTop,
            width: fridgeWidth,
            height: fridgeHeight,
            child: Opacity(
              opacity: fridgeOpacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: fridgeScale,
                alignment: Alignment.center,
                child: FridgeCabinetWidget(
                  width: fridgeWidth,
                  height: fridgeHeight,
                  interiorGlowProgress: interiorGlow,
                ),
              ),
            ),
          ),

        // 4. Floating Fresh Ingredients (Emerging from shelves, orbiting, and swirling)
        if (t >= 0.27 && t < 0.83)
          Positioned.fill(
            child: FloatingIngredientsWidget(
              progress: t,
              canvasWidth: screenWidth,
              canvasHeight: screenHeight,
              fridgeCenter: centerOffset + Offset(0, fridgeY),
              fridgeWidth: fridgeWidth,
              fridgeHeight: fridgeHeight,
              ringRotation: ringRotation,
              ringContract: ringContract,
            ),
          ),

        // 5. Refrigerator Door (In-place magical dissolve overlay)
        if (fridgeOpacity > 0.01 && doorOpacity > 0.005)
          Positioned(
            left: fridgeLeft,
            top: fridgeTop,
            width: fridgeWidth,
            height: fridgeHeight,
            child: Opacity(
              opacity: fridgeOpacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: fridgeScale,
                alignment: Alignment.center,
                child: FridgeDoorWidget(
                  width: fridgeWidth,
                  height: fridgeHeight,
                  doorOpacity: doorOpacity,
                ),
              ),
            ),
          ),

        // 6. Orbital Freshness Ring (Progressive draw & dynamic rotation)
        if (freshnessRingOpacity > 0.01)
          Positioned.fill(
            child: CustomPaint(
              painter: FreshnessRingPainter(
                center: centerOffset,
                radius: screenWidth * 0.38,
                progress: freshnessRingProgress,
                rotation: ringRotation,
                opacity: freshnessRingOpacity,
              ),
            ),
          ),

        // 7. Uncluttered NutriFridge Brand Logo Payoff (Scene 5 & 6)
        if (brandProgress > 0.01)
          Positioned.fill(
            child: NutriFridgeBrandReveal(
              progress: brandProgress,
              canvasWidth: screenWidth,
            ),
          ),
      ],
    );
  }
}
