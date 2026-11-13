import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/food_image/food_image_resolver.dart';
import '../models/category_item.dart';
import '../models/fridge_preferences.dart';
import '../models/ingredient_addition_data.dart';
import 'top_freezer_refrigerator.dart';

/// Cinematic Refrigerator Opening & Ingredient Addition Experience.
///
/// Animation lifecycle (approximately 2.5–3.2 seconds):
/// 1. Scene 1 — Fridge Door Vanish/Fade: The exact NutriFridge refrigerator is displayed. Its door smoothly blurs and fades away, revealing the interior cavity and releasing a cool mist.
/// 2. Scene 2 — Ingredients Fly In: Confirmed ingredients follow staggered, curved, rotating trajectories into the revealed interior with depth scaling.
/// 3. Scene 3 — Fridge Door Re-Fade: Interior glow settles, and the refrigerator door smoothly fades back in to close the appliance.
/// 4. Scene 4 — Addition Summary Screen: Dedicated full-screen card summary displaying real saved ingredients, quantities, categories, and optional expiry dates.
///
/// Features:
/// - Reuses the exact authentic NutriFridge [TopFreezerRefrigerator] component.
/// - Door disappears and restores via soft blur and opacity fade (zero conventional swinging-door rotation).
/// - Tap anywhere to skip straight to the summary screen.
/// - "Done" button returns user to the originating screen.
/// - Reduced-motion accessibility support.
/// - Reentrancy guard preventing duplicate animation launches.
class CinematicFridgeAdditionScreen extends StatefulWidget {
  final IngredientAdditionData additionData;
  final VoidCallback? onDone;

  const CinematicFridgeAdditionScreen({
    super.key,
    required this.additionData,
    this.onDone,
  });

  /// Static guard preventing duplicate animation launches from rapid callbacks.
  @visibleForTesting
  static bool isShowing = false;

  /// Helper to safely launch the full-screen cinematic experience.
  static Future<void> show(
    BuildContext context, {
    required IngredientAdditionData additionData,
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
            return CinematicFridgeAdditionScreen(
              additionData: additionData,
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
  State<CinematicFridgeAdditionScreen> createState() =>
      _CinematicFridgeAdditionScreenState();
}

class _CinematicFridgeAdditionScreenState
    extends State<CinematicFridgeAdditionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final List<_FlyingFridgeItem> _flyingItems;

  bool _isFridgeOpen = false;
  bool _isFreezerOpen = false;

  static const Duration _totalDuration = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    _initFlyingItems();

    _controller.addListener(_handleAnimationTick);

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
    _controller.removeListener(_handleAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationTick() {
    final t = _controller.value;
    // Sequence:
    // 0.00..0.06: Complete refrigerator with door visible
    // 0.06..0.64: Door fades away, interior fully revealed, mist emerges, ingredients fly in
    // 0.64..0.80: Refrigerator door smoothly returns via reverse fade
    // 0.80..1.00: Refrigerator closed, transitions to Summary screen
    final shouldOpen = (t >= 0.06 && t < 0.64);
    if (shouldOpen != _isFridgeOpen && mounted) {
      setState(() {
        _isFridgeOpen = shouldOpen;
        _isFreezerOpen = shouldOpen;
      });
    }
  }

  void _initFlyingItems() {
    final items = widget.additionData.items;
    final rng = math.Random(widget.additionData.addedAt.millisecondsSinceEpoch);

    final List<AddedIngredientItem> visualEntities = [];
    if (items.length == 1) {
      visualEntities.addAll([items[0], items[0]]);
    } else if (items.length == 2) {
      visualEntities.addAll([items[0], items[1]]);
    } else {
      visualEntities.addAll(items.take(5));
    }

    _flyingItems = List.generate(visualEntities.length, (index) {
      final item = visualEntities[index];
      final imagePath = item.imageAsset ??
          FoodImageResolver.findCuratedCutout(item.name) ??
          FoodItemAssetRegistry.getAssetForItem(item.name, item.category);

      final total = visualEntities.length.toDouble();
      final double horizontalOffsetFactor = (index - (total - 1) / 2.0);

      // Staggered launch times: 0.22 to 0.45
      final double startT = 0.22 + (index * 0.045);
      final double endT = (startT + 0.38).clamp(0.0, 0.68);

      // Launch positions spread from bottom corners outside fridge
      final bool startLeft = index % 2 == 0;
      final double launchX = startLeft ? -160.0 - (index * 20.0) : 160.0 + (index * 20.0);
      final double launchY = 190.0 + (rng.nextDouble() * 30.0);

      // Apex curves up and high toward the open interior
      final double apexX = startLeft ? -80.0 + horizontalOffsetFactor * 15.0 : 80.0 + horizontalOffsetFactor * 15.0;
      final double apexY = -100.0 - (rng.nextDouble() * 50.0);

      // Destination inside the open fridge cabinet compartment
      final double targetX = (horizontalOffsetFactor * 18.0);
      final double targetY = 10.0 + (index * 16.0);

      final double spinDir = (index % 2 == 0) ? 1.0 : -1.0;
      final double spinSpeed = (rng.nextDouble() * 1.5 + 1.2) * spinDir;

      return _FlyingFridgeItem(
        item: item,
        assetPath: imagePath,
        startT: startT,
        endT: endT,
        launchX: launchX,
        launchY: launchY,
        apexX: apexX,
        apexY: apexY,
        targetX: targetX,
        targetY: targetY,
        spinSpeed: spinSpeed,
      );
    });
  }

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
                // 1. Soft Sage / Mint Atmosphere Background
                _buildSageMintBackground(t),

                // 2. Scene 1, 2, 3: The Authentic NutriFridge Refrigerator, Cold Mist, and Flying Ingredients
                if (t < 0.85) ...[
                  _buildFridgeScenes(t),
                ],

                // 3. Scene 4: Ingredients Added Summary Screen
                if (t >= 0.70) ...[
                  _buildSummaryScreen(t),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Ambient environment background
  Widget _buildSageMintBackground(double t) {
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

  /// Scene 1, Scene 2, Scene 3: Actual NutriFridge Refrigerator with fade-reveal door
  Widget _buildFridgeScenes(double t) {
    final sceneOpacity = (1.0 - ((t - 0.72) / 0.12)).clamp(0.0, 1.0);
    if (sceneOpacity <= 0) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final double fridgeHeight = size.height * 0.58;
    final double centerX = size.width / 2;
    final double centerY = size.height * 0.38;

    return Opacity(
      opacity: sceneOpacity,
      child: Stack(
        children: [
          // Authentic NutriFridge Refrigerator (Fade-reveal door, shelves & cold mist)
          Positioned(
            top: size.height * 0.08,
            left: 0,
            right: 0,
            height: fridgeHeight,
            child: Center(
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 292.0,
                    height: 588.0,
                    child: TopFreezerRefrigerator(
                      isFreezerOpen: _isFreezerOpen,
                      isFridgeOpen: _isFridgeOpen,
                      onFreezerToggle: () {},
                      onFridgeToggle: () {},
                      preferences: FridgePreferencesRepository.current,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Flying Ingredients with curved trajectories entering the open compartment
          ..._flyingItems.map((flying) {
            return _buildFlyingIngredientItem(flying, t, centerX, centerY);
          }),
        ],
      ),
    );
  }

  /// Single flying ingredient moving along its curved flight path
  Widget _buildFlyingIngredientItem(
    _FlyingFridgeItem flying,
    double t,
    double centerX,
    double centerY,
  ) {
    if (t < flying.startT) return const SizedBox.shrink();

    // Flight progress: 0.0 (launch) -> 1.0 (entered fridge)
    final s = ((t - flying.startT) / (flying.endT - flying.startT)).clamp(0.0, 1.0);
    final oneMinusS = 1.0 - s;

    // Curved Quadratic Bézier
    final p0x = centerX + flying.launchX;
    final p0y = centerY + flying.launchY;
    final p1x = centerX + flying.apexX;
    final p1y = centerY + flying.apexY;
    final p2x = centerX + flying.targetX;
    final p2y = centerY + flying.targetY;

    final curX = (oneMinusS * oneMinusS * p0x) + (2 * oneMinusS * s * p1x) + (s * s * p2x);
    final curY = (oneMinusS * oneMinusS * p0y) + (2 * oneMinusS * s * p1y) + (s * s * p2y);

    // Natural 3D Rotation
    final rotation = flying.spinSpeed * s * math.pi;

    // Scale arc: starts 0.95 outside, peaks 1.15 in mid-air near camera, shrinks to 0.65 as it enters shelves
    final scalePeak = math.sin(s * math.pi);
    final scale = 0.95 + (scalePeak * 0.25) - (s * 0.40);

    // Disappearance into the fridge compartment: fades out gracefully right at entrance
    final entranceOpacity = (1.0 - math.pow(s, 5)).clamp(0.0, 1.0).toDouble();

    return Positioned(
      left: curX - 28,
      top: curY - 28,
      child: Opacity(
        opacity: entranceOpacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateZ(rotation)
            ..scale(scale),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18 * (1.0 - s * 0.5)),
                  blurRadius: 14,
                  offset: Offset(0, (1.0 - s) * 12 + 4),
                ),
              ],
            ),
            child: _buildIngredientThumbnail(flying.item.name, flying.assetPath),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientThumbnail(String name, String? assetPath) {
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackThumbnail(name),
      );
    }
    return _buildFallbackThumbnail(name);
  }

  Widget _buildFallbackThumbnail(String name) {
    final clean = name.trim();
    final letter = clean.isNotEmpty ? clean[0].toUpperCase() : '•';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paleMint,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.freshGreen.withOpacity(0.4), width: 2),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryForest,
          ),
        ),
      ),
    );
  }

  /// Scene 4 — Ingredient Addition Summary Screen
  Widget _buildSummaryScreen(double t) {
    final summaryProgress = ((t - 0.70) / 0.25).clamp(0.0, 1.0);
    final easeP = Curves.easeOutCubic.transform(summaryProgress);

    final headerOpacity = ((summaryProgress - 0.0) / 0.5).clamp(0.0, 1.0);
    final listOpacity = ((summaryProgress - 0.2) / 0.5).clamp(0.0, 1.0);
    final btnOpacity = ((summaryProgress - 0.4) / 0.5).clamp(0.0, 1.0);

    final items = widget.additionData.items;

    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Header Section
              Opacity(
                opacity: headerOpacity,
                child: Transform.translate(
                  offset: Offset(0, (1.0 - easeP) * 24),
                  child: _buildSummaryHeader(items.length),
                ),
              ),

              const SizedBox(height: 20),

              // Scrollable Ingredient Cards List
              Expanded(
                child: Opacity(
                  opacity: listOpacity,
                  child: Transform.translate(
                    offset: Offset(0, (1.0 - Curves.easeOut.transform(listOpacity)) * 20),
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildIngredientCard(items[index]);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Done Primary Button
              Opacity(
                opacity: btnOpacity,
                child: Transform.translate(
                  offset: Offset(0, (1.0 - Curves.easeOut.transform(btnOpacity)) * 16),
                  child: _buildDoneButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header with success pill badge and title
  Widget _buildSummaryHeader(int count) {
    return Column(
      children: [
        // Success Pill Badge
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
                'Inventory Updated',
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

        // Prominent Header
        Text(
          'Ingredients Added Successfully',
          textAlign: TextAlign.center,
          style: AppTypography.displayLarge.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.darkText,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Added $count ${count == 1 ? 'item' : 'items'} to your fridge',
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

  /// Single Ingredient Card
  Widget _buildIngredientCard(AddedIngredientItem item) {
    final imagePath = item.imageAsset ??
        FoodImageResolver.findCuratedCutout(item.name) ??
        FoodItemAssetRegistry.getAssetForItem(item.name, item.category);

    final expiryText = item.formattedExpiry;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryForest.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ingredient Thumbnail
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.paleMint.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: _buildIngredientThumbnail(item.name, imagePath),
          ),

          const SizedBox(width: 14),

          // Name, Quantity, Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Quantity Added
                    Text(
                      item.formattedQuantity,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryForest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Category Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.softCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.subtleBorder),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expiry Label (Strictly shown only when available)
          if (expiryText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expiryText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Primary Done button
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

/// Helper model for flying ingredient animation
class _FlyingFridgeItem {
  final AddedIngredientItem item;
  final String? assetPath;
  final double startT;
  final double endT;
  final double launchX;
  final double launchY;
  final double apexX;
  final double apexY;
  final double targetX;
  final double targetY;
  final double spinSpeed;

  _FlyingFridgeItem({
    required this.item,
    this.assetPath,
    required this.startT,
    required this.endT,
    required this.launchX,
    required this.launchY,
    required this.apexX,
    required this.apexY,
    required this.targetX,
    required this.targetY,
    required this.spinSpeed,
  });
}
