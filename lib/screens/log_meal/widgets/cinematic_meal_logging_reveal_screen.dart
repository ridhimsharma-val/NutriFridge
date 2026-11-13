import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/food_image/food_image_resolver.dart';
import '../../../services/food_image/food_image_service.dart';
import '../models/cinematic_meal_data.dart';

/// Cinematic Meal Logging & Nutrition Reveal Animation Screen.
///
/// Features a 3-stage animated transition:
/// 1. Scene 1 — The Pan Toss (~700–900ms): 3D-style cooking pan tosses actual meal ingredients upward.
/// 2. Scene 2 — Ingredients in the Air (~900–1200ms): Actual meal ingredients fly along curved trajectories with organic 3D rotations, perspective depth and dynamic shadows, converging into the completed meal.
/// 3. Scene 3 — Nutrition Reveal (~600–900ms): Completed meal hero presentation with prominent meal name, "Meal Logged Successfully" confirmation, and staggered macro/micro nutrition cards.
///
/// Tap anywhere to skip straight to the nutrition details.
/// "Done" button returns user to previous screen.
class CinematicMealLoggingRevealScreen extends StatefulWidget {
  final CinematicMealData mealData;
  final VoidCallback? onDone;

  const CinematicMealLoggingRevealScreen({
    super.key,
    required this.mealData,
    this.onDone,
  });

  /// Static guard against duplicate animation launches from rapid callbacks.
  @visibleForTesting
  static bool isShowing = false;

  /// Helper to safely launch the full-screen cinematic reveal screen.
  static Future<void> show(
    BuildContext context, {
    required CinematicMealData mealData,
    VoidCallback? onDone,
  }) async {
    if (isShowing) return;
    isShowing = true;

    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return CinematicMealLoggingRevealScreen(
              mealData: mealData,
              onDone: onDone,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } finally {
      isShowing = false;
    }
  }

  @override
  State<CinematicMealLoggingRevealScreen> createState() =>
      _CinematicMealLoggingRevealScreenState();
}

class _CinematicMealLoggingRevealScreenState
    extends State<CinematicMealLoggingRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Staggered flight items for the actual ingredients
  late final List<_FlyingIngredientModel> _flyingIngredients;

  static const Duration _totalDuration = Duration(milliseconds: 2700);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    _initFlyingIngredients();

    // Check accessibility reduced-motion preference on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Parses the actual meal ingredients and constructs realistic trajectories.
  void _initFlyingIngredients() {
    final rawIngredients = widget.mealData.ingredients;
    final List<String> targetNames = [];

    if (rawIngredients.isNotEmpty) {
      for (final ing in rawIngredients) {
        // Strip out quantity annotations like "(1 cup)", "(200g)"
        final clean = ing.split('(').first.replaceAll(RegExp(r'\d+'), '').trim();
        if (clean.isNotEmpty) {
          targetNames.add(clean);
        }
      }
    }

    // If still empty, derive from meal name
    if (targetNames.isEmpty) {
      final mealLower = widget.mealData.mealName.toLowerCase();
      if (mealLower.contains('banana')) targetNames.add('banana');
      if (mealLower.contains('shake') || mealLower.contains('smoothie')) targetNames.add('milk');
      if (mealLower.contains('egg')) targetNames.add('egg');
      if (mealLower.contains('chicken')) targetNames.add('chicken');
      if (mealLower.contains('salad')) {
        targetNames.addAll(['tomato', 'broccoli', 'lemon']);
      } else if (mealLower.contains('paneer')) {
        targetNames.addAll(['paneer', 'capsicum', 'tomato']);
      } else if (mealLower.contains('fruit')) {
        targetNames.addAll(['apple', 'banana', 'orange']);
      } else {
        targetNames.addAll(['apple', 'milk']);
      }
    }

    // Ensure at least 3-5 visual items by repeating or slicing if few ingredients
    final List<String> finalDisplayList = [];
    if (targetNames.length == 1) {
      finalDisplayList.addAll([targetNames[0], targetNames[0], targetNames[0], targetNames[0]]);
    } else if (targetNames.length == 2) {
      finalDisplayList.addAll([targetNames[0], targetNames[1], targetNames[0], targetNames[1]]);
    } else {
      finalDisplayList.addAll(targetNames.take(6));
    }

    final rng = math.Random(widget.mealData.mealName.hashCode);

    _flyingIngredients = List.generate(finalDisplayList.length, (index) {
      final name = finalDisplayList[index];
      final cutout = FoodImageResolver.findCuratedCutout(name) ??
          FoodImageService.instance.getPanCutoutSync(name: name);

      // Trajectory geometry
      final double totalItems = finalDisplayList.length.toDouble();
      final double horizontalFactor = (index - (totalItems - 1) / 2.0) / (totalItems / 2.0);

      // Spread arc: outer items spread wider, inner items fly higher
      final double apexX = horizontalFactor * 130.0 + (rng.nextDouble() * 20.0 - 10.0);
      final double apexY = -220.0 - (1.0 - horizontalFactor.abs()) * 60.0 + (rng.nextDouble() * 30.0);

      // Convergence target around the hero meal plate center
      final double targetX = horizontalFactor * 32.0;
      final double targetY = -40.0 + (rng.nextDouble() * 20.0 - 10.0);

      // Launch time stagger: 0.16 to 0.32
      final double startT = 0.16 + (index * 0.032);
      final double endT = (startT + 0.38).clamp(0.0, 0.68);

      final double spinDirection = (index % 2 == 0) ? 1.0 : -1.0;
      final double spinSpeed = (rng.nextDouble() * 1.5 + 1.2) * spinDirection;

      return _FlyingIngredientModel(
        name: name,
        assetPath: cutout,
        startT: startT,
        endT: endT,
        apexX: apexX,
        apexY: apexY,
        targetX: targetX,
        targetY: targetY,
        spinSpeed: spinSpeed,
        perspectiveTiltX: (rng.nextDouble() * 0.3 - 0.15),
        perspectiveTiltY: (rng.nextDouble() * 0.4 - 0.2),
      );
    });
  }

  /// Skips immediately to the final nutrition details state.
  void _skipAnimation() {
    if (_controller.value < 1.0) {
      _controller.animateTo(
        1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleDone() {
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skipAnimation,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Premium Sage / Mint Environment Background
                _buildSageMintBackground(t),

                // 2. Scene 1 & 2: The Pan Toss & Flying Ingredients
                if (t < 0.75) ...[
                  _buildPanTossAndIngredients(t),
                ],

                // 3. Scene 3: Nutrition Reveal Details
                if (t >= 0.55) ...[
                  _buildNutritionRevealDetails(t),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Premium sage/mint gradient environment
  Widget _buildSageMintBackground(double t) {
    // Smooth transition into a soothing, luxurious mint background
    final bgProgress = (t / 0.35).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              const Color(0xFFF7FAF8),
              const Color(0xFFEAF5EE),
              bgProgress,
            )!,
            Color.lerp(
              const Color(0xFFEBF4EF),
              const Color(0xFFDAECE0),
              bgProgress,
            )!,
            Color.lerp(
              const Color(0xFFE2EFE7),
              const Color(0xFFCBE3D4),
              bgProgress,
            )!,
          ],
        ),
      ),
    );
  }

  /// Scene 1 & Scene 2: Cooking pan squash-and-stretch toss + ingredients flight
  Widget _buildPanTossAndIngredients(double t) {
    // Opacity fades out after convergence: 0.60 -> 0.72
    final sceneOpacity = (1.0 - ((t - 0.60) / 0.12)).clamp(0.0, 1.0);
    if (sceneOpacity <= 0) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height * 0.58;

    // Pan Toss Animation Timeline:
    // 0.00..0.08: Pan squashes down (gather energy)
    // 0.08..0.20: Rapid upward snap toss & forward tilt
    // 0.20..0.35: Pan catches & settles back down
    // 0.45..0.70: Pan sinks off-screen
    double panY = 0.0;
    double panScaleX = 1.0;
    double panScaleY = 1.0;
    double panTiltX = 0.0;
    double panTiltZ = 0.0;

    if (t < 0.08) {
      final p = t / 0.08;
      panY = p * 14.0;
      panScaleX = 1.0 + (p * 0.06);
      panScaleY = 1.0 - (p * 0.06);
    } else if (t < 0.20) {
      final p = (t - 0.08) / 0.12;
      // High-energy upward toss
      final easeUp = Curves.easeOutCubic.transform(p);
      panY = 14.0 - (easeUp * 74.0);
      panScaleX = 1.06 - (easeUp * 0.14);
      panScaleY = 0.94 + (easeUp * 0.18);
      panTiltX = easeUp * 0.24; // Tilt forward
      panTiltZ = -easeUp * 0.07;
    } else if (t < 0.35) {
      final p = (t - 0.20) / 0.15;
      final easeSettle = Curves.easeInOutCubic.transform(p);
      panY = -60.0 + (easeSettle * 60.0);
      panScaleX = 0.92 + (easeSettle * 0.08);
      panScaleY = 1.12 - (easeSettle * 0.12);
      panTiltX = 0.24 - (easeSettle * 0.24);
      panTiltZ = -0.07 + (easeSettle * 0.07);
    } else if (t < 0.45) {
      panY = 0.0;
    } else {
      // Pan slides down offscreen
      final p = ((t - 0.45) / 0.25).clamp(0.0, 1.0);
      panY = Curves.easeInCubic.transform(p) * 220.0;
    }

    return Opacity(
      opacity: sceneOpacity,
      child: Stack(
        children: [
          // Background Pan Shadow
          Positioned(
            left: centerX - 120,
            top: centerY + 70 + panY * 0.4,
            child: Container(
              width: 240,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(240, 40)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryForest.withOpacity(0.18),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // The 3D Cooking Pan
          Positioned(
            left: centerX - 140,
            top: centerY - 40 + panY,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateX(panTiltX)
                ..rotateZ(panTiltZ)
                ..scale(panScaleX, panScaleY),
              child: _buildPanAsset(),
            ),
          ),

          // Flying Ingredients with curved trajectories & 3D perspective
          ..._flyingIngredients.map((item) {
            return _buildFlyingIngredient(item, t, centerX, centerY + panY);
          }),
        ],
      ),
    );
  }

  /// Renders the pan image asset with fallback
  Widget _buildPanAsset() {
    return SizedBox(
      width: 280,
      height: 150,
      child: Image.asset(
        'assets/images/cooking_pan.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackPan(),
      ),
    );
  }

  /// Fallback high-fidelity vector pan if asset is absent
  Widget _buildFallbackPan() {
    return Center(
      child: Container(
        width: 240,
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF263238),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(55),
            bottomRight: Radius.circular(55),
          ),
          border: Border.all(color: const Color(0xFF455A64), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.soup_kitchen_rounded,
            size: 44,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  /// Renders a single ingredient flying out of the pan along its curved trajectory
  Widget _buildFlyingIngredient(
    _FlyingIngredientModel item,
    double t,
    double originX,
    double originY,
  ) {
    if (t < item.startT) return const SizedBox.shrink();

    // Normalized flight progress: 0.0 (launch) -> 1.0 (landing)
    final flightT = ((t - item.startT) / (item.endT - item.startT)).clamp(0.0, 1.0);

    // Quadratic Bezier Curve:
    // P0: Launch point in the pan (originX, originY)
    // P1: Apex high above the pan (originX + apexX, originY + apexY)
    // P2: Convergence target in hero plate (originX + targetX, originY + targetY)
    final double s = flightT;
    final double oneMinusS = 1.0 - s;

    final double p0x = originX;
    final double p0y = originY;
    final double p1x = originX + item.apexX;
    final double p1y = originY + item.apexY;
    final double p2x = originX + item.targetX;
    final double p2y = originY + item.targetY;

    final double curX = (oneMinusS * oneMinusS * p0x) +
        (2 * oneMinusS * s * p1x) +
        (s * s * p2x);
    final double curY = (oneMinusS * oneMinusS * p0y) +
        (2 * oneMinusS * s * p1y) +
        (s * s * p2y);

    // 3D Rotation & Perspective Spin
    final double currentRotation = item.spinSpeed * s * math.pi;

    // Scale arc: starts at 0.70, peaks at 1.15 at apex (feels like it flies toward camera), settles to 0.95
    final double scalePeak = math.sin(s * math.pi);
    final double currentScale = 0.70 + (scalePeak * 0.45) + (s * 0.25);

    // Dynamic depth shadow: blur and offset scale with height
    final double shadowOffset = (1.0 - s) * 20.0 + 6.0;
    final double shadowBlur = (1.0 - s) * 16.0 + 8.0;

    return Positioned(
      left: curX - 30,
      top: curY - 30,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(item.perspectiveTiltX * math.sin(s * math.pi))
          ..rotateY(item.perspectiveTiltY * math.cos(s * math.pi))
          ..rotateZ(currentRotation)
          ..scale(currentScale),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18 * (1.0 - s * 0.4)),
                offset: Offset(0, shadowOffset),
                blurRadius: shadowBlur,
              ),
            ],
          ),
          child: _buildIngredientVisual(item.name, item.assetPath),
        ),
      ),
    );
  }

  /// Ingredient image cutout or styled vector representation
  Widget _buildIngredientVisual(String name, String? assetPath) {
    if (assetPath != null && assetPath.isNotEmpty) {
      if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
        return Image.network(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackIngredientChip(name),
        );
      }
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackIngredientChip(name),
      );
    }
    return _buildFallbackIngredientChip(name);
  }

  Widget _buildFallbackIngredientChip(String name) {
    final clean = name.trim();
    final firstChar = clean.isNotEmpty ? clean[0].toUpperCase() : '•';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paleMint,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.freshGreen.withOpacity(0.4), width: 2),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryForest,
          ),
        ),
      ),
    );
  }

  /// Scene 3: Nutrition Reveal Details Screen
  Widget _buildNutritionRevealDetails(double t) {
    // Reveal transition progress: 0.60 -> 0.95
    final revealP = ((t - 0.60) / 0.35).clamp(0.0, 1.0);
    final easeP = Curves.easeOutCubic.transform(revealP);

    // Staggered slide/fade curves
    final heroOpacity = ((revealP - 0.0) / 0.4).clamp(0.0, 1.0);
    final card1Progress = ((revealP - 0.2) / 0.4).clamp(0.0, 1.0);
    final card2Progress = ((revealP - 0.4) / 0.4).clamp(0.0, 1.0);
    final btnProgress = ((revealP - 0.5) / 0.4).clamp(0.0, 1.0);

    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // 1. Completed Meal Hero Image & Success Pill
                      Opacity(
                        opacity: heroOpacity,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - easeP) * 30),
                          child: _buildMealHeaderSection(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 2. Nutrition Overview — Hero Calories Card
                      Opacity(
                        opacity: card1Progress,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - Curves.easeOut.transform(card1Progress)) * 24),
                          child: _buildHeroCaloriesCard(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3. Macronutrients 3-Column Grid
                      Opacity(
                        opacity: card1Progress,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - Curves.easeOut.transform(card1Progress)) * 24),
                          child: _buildMacroNutrientsRow(),
                        ),
                      ),

                      // 4. Additional Nutrition (Render ONLY if genuine data exists)
                      if (_hasAdditionalNutrients) ...[
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: card2Progress,
                          child: Transform.translate(
                            offset: Offset(0, (1.0 - Curves.easeOut.transform(card2Progress)) * 24),
                            child: _buildAdditionalNutritionCard(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 5. Clean "Done" Button
              Opacity(
                opacity: btnProgress,
                child: Transform.translate(
                  offset: Offset(0, (1.0 - Curves.easeOut.transform(btnProgress)) * 20),
                  child: _buildDoneButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header with Hero Meal Artwork, Success Pill, and Meal Name
  Widget _buildMealHeaderSection() {
    final meal = widget.mealData;

    return Column(
      children: [
        // Completed Meal Hero Presentation
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.paleMint, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryForest.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: (meal.imageUrl != null && meal.imageUrl!.isNotEmpty)
                ? Image.asset(
                    meal.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildHeroFallbackIcon(),
                  )
                : _buildHeroFallbackIcon(),
          ),
        ),

        const SizedBox(height: 16),

        // Success Status Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.paleMint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.freshGreen.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.freshGreen,
              ),
              SizedBox(width: 6),
              Text(
                'Meal Logged Successfully',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryForest,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Prominent Meal Name
        Text(
          meal.mealName,
          textAlign: TextAlign.center,
          style: AppTypography.displayLarge.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.darkText,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 6),

        // Metadata: Logged time • Meal slot • Serving size
        Text(
          _buildMealMetadataString(),
          textAlign: TextAlign.center,
          style: AppTypography.subtitle.copyWith(
            fontSize: 13,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroFallbackIcon() {
    return Center(
      child: Container(
        color: AppColors.paleMint.withOpacity(0.6),
        child: const Center(
          child: Icon(
            Icons.restaurant_rounded,
            size: 44,
            color: AppColors.primaryForest,
          ),
        ),
      ),
    );
  }

  String _buildMealMetadataString() {
    final type = widget.mealData.mealType;
    if (type != null && type.trim().isNotEmpty) {
      final clean = type.trim();
      return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
    }
    return 'Meal';
  }

  /// Large Calories Hero Card
  Widget _buildHeroCaloriesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryForest.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 28,
              color: Color(0xFFFF6D3B),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ENERGY LOGGED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${widget.mealData.calories}',
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3-Column Macro Nutrients Row (Protein, Carbs, Fat)
  Widget _buildMacroNutrientsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMacroCard(
            title: 'Protein',
            value: '${widget.mealData.proteinGrams.round()}g',
            color: const Color(0xFF2E7D32),
            bgColor: const Color(0xFFE8F5E9),
            icon: Icons.fitness_center_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMacroCard(
            title: 'Carbs',
            value: '${widget.mealData.carbsGrams.round()}g',
            color: const Color(0xFFE65100),
            bgColor: const Color(0xFFFFF3E0),
            icon: Icons.grain_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMacroCard(
            title: 'Fat',
            value: '${widget.mealData.fatGrams.round()}g',
            color: const Color(0xFF00695C),
            bgColor: const Color(0xFFE0F2F1),
            icon: Icons.opacity_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryForest.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasAdditionalNutrients {
    final m = widget.mealData;
    return m.fiberGrams != null ||
        m.sugarGrams != null ||
        m.sodiumMg != null ||
        m.potassiumMg != null ||
        m.extraNutrients.isNotEmpty;
  }

  /// Additional Nutrients Row — Shown ONLY if real data exists. Never fabricated.
  Widget _buildAdditionalNutritionCard() {
    final m = widget.mealData;
    final List<Widget> items = [];

    if (m.fiberGrams != null) {
      items.add(_buildMicroPill('Fibre', '${m.fiberGrams!.toStringAsFixed(1)}g'));
    }
    if (m.sugarGrams != null) {
      items.add(_buildMicroPill('Sugar', '${m.sugarGrams!.toStringAsFixed(1)}g'));
    }
    if (m.sodiumMg != null) {
      items.add(_buildMicroPill('Sodium', '${m.sodiumMg!.toInt()}mg'));
    }
    if (m.potassiumMg != null) {
      items.add(_buildMicroPill('Potassium', '${m.potassiumMg!.toInt()}mg'));
    }
    for (final entry in m.extraNutrients.entries) {
      items.add(_buildMicroPill(entry.key, entry.value));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADDITIONAL NUTRITION',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items,
          ),
        ],
      ),
    );
  }

  Widget _buildMicroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.paleMint.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.subtleBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryForest,
            ),
          ),
        ],
      ),
    );
  }

  /// Clean, accessible "Done" button at bottom of screen
  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _handleDone,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryForest,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Helper model encapsulating dynamic curved flight trajectory for a single ingredient
class _FlyingIngredientModel {
  final String name;
  final String? assetPath;
  final double startT;
  final double endT;
  final double apexX;
  final double apexY;
  final double targetX;
  final double targetY;
  final double spinSpeed;
  final double perspectiveTiltX;
  final double perspectiveTiltY;

  _FlyingIngredientModel({
    required this.name,
    this.assetPath,
    required this.startT,
    required this.endT,
    required this.apexX,
    required this.apexY,
    required this.targetX,
    required this.targetY,
    required this.spinSpeed,
    required this.perspectiveTiltX,
    required this.perspectiveTiltY,
  });
}
