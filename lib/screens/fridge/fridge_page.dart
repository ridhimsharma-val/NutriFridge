import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'models/category_item.dart';
import 'models/fridge_preferences.dart';
import 'screens/cooking_workspace_screen.dart';
import 'services/cooking_basket_service.dart';
import 'widgets/category_bottom_sheet.dart';
import 'widgets/cooking_pan_visual.dart';
import 'widgets/cooking_pan_widget.dart';
import 'widgets/expiring_soon_bottom_sheet.dart';
import 'widgets/fridge_header.dart';
import 'widgets/fridge_preferences_sheet.dart';
import 'widgets/top_freezer_refrigerator.dart';
import 'widgets/use_soon_section.dart';

class FridgePage extends StatefulWidget {
  final bool isSelectionMode;

  const FridgePage({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  final GlobalKey _mainPanKey = GlobalKey();

  // Independent door states: Top Freezer and Lower Refrigerator.
  // In selection mode ("Use My Ingredients"), doors default to open immediately
  // so category shelves and inventory are instantly visible and accessible.
  late bool _isFreezerOpen;
  late bool _isFridgeOpen;

  @override
  void initState() {
    super.initState();
    _isFreezerOpen = widget.isSelectionMode;
    _isFridgeOpen = widget.isSelectionMode;
    if (widget.isSelectionMode) {
      CookingPanCoordinator.mainPanKey = _mainPanKey;
      CookingPanCoordinator.activeTargetKey = _mainPanKey;
    }
    if (!FridgeCategoryRepository.isLoadedFromSupabase &&
        !FridgeCategoryRepository.isLoading) {
      FridgeCategoryRepository.loadFromSupabase();
    }
  }

  @override
  void dispose() {
    if (CookingPanCoordinator.mainPanKey == _mainPanKey) {
      CookingPanCoordinator.mainPanKey = null;
    }
    if (CookingPanCoordinator.activeTargetKey == _mainPanKey) {
      CookingPanCoordinator.activeTargetKey = null;
    }
    super.dispose();
  }

  void _openCookingWorkspace(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CookingWorkspaceScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  void _toggleFreezer() {
    setState(() {
      _isFreezerOpen = !_isFreezerOpen;
    });
  }

  void _toggleFridge() {
    setState(() {
      _isFridgeOpen = !_isFridgeOpen;
    });
  }

  bool _isNavigatingCategory = false;
  String? _highlightedCategory;

  void _onCategoryTap(String categoryLabel) async {
    if (_isNavigatingCategory) return;
    _isNavigatingCategory = true;

    setState(() {
      _highlightedCategory = categoryLabel;
    });

    // Subtle shelf highlight delay (~220ms) before opening sheet
    await Future.delayed(const Duration(milliseconds: 220));

    if (!mounted) {
      _isNavigatingCategory = false;
      return;
    }

    final categoryData =
        FridgeCategoryRepository.getCategoryData(categoryLabel);
    await CategoryBottomSheet.show(
      context: context,
      category: categoryData,
      isSelectionMode: widget.isSelectionMode,
    );
    if (mounted) {
      setState(() {
        _highlightedCategory = null;
        _isNavigatingCategory = false;
      });
    } else {
      _isNavigatingCategory = false;
    }
  }

  void _openExpiringSoon() async {
    await ExpiringSoonBottomSheet.show(context: context);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FridgeCategoryRepository.notifier,
        FridgePreferencesRepository.notifier,
        CookingBasketService.selectedItemsNotifier,
      ]),
      builder: (context, _) {
        final totalItems = FridgeCategoryRepository.totalFridgeItems;
        final expiringCount = FridgeCategoryRepository.expiringSoonCount;
        final selectedCount = CookingBasketService.count;

        return Scaffold(
          primary: false,
          resizeToAvoidBottomInset: widget.isSelectionMode,
          backgroundColor: widget.isSelectionMode ? AppColors.warmCream : Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Header: My Fridge / Select Ingredients | dynamic items | dynamic expiring soon | preferences control
                FridgeHeader(
                  title: widget.isSelectionMode ? 'Select Ingredients' : 'My Fridge',
                  itemCount: totalItems,
                  expiringCount: expiringCount,
                  isSelectionMode: widget.isSelectionMode,
                  selectedCount: selectedCount,
                  onBackTap: widget.isSelectionMode
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  onExpiringTap: _openExpiringSoon,
                  onActionTap: () async {
                    await FridgePreferencesSheet.show(context);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),

                if (FridgeCategoryRepository.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B7E58)),
                  ),

                if (FridgeCategoryRepository.loadError != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBEBEA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF09995)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Color(0xFFC53929)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            FridgeCategoryRepository.loadError!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFC53929)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => FridgeCategoryRepository.loadFromSupabase(force: true),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC53929))),
                        ),
                      ],
                    ),
                  ),

                // 1.5 Smart Fridge Intelligence: Use Soon Section
                if (!widget.isSelectionMode)
                  const UseSoonSection(),

                // 2. Main Centralized Appliance Area (Positioned immediately below header, fitted without scrolling)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 2.0, 16.0, 6.0),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 292.0,
                              height: 588.0,
                              child: TopFreezerRefrigerator(
                                isFreezerOpen: _isFreezerOpen,
                                isFridgeOpen: _isFridgeOpen,
                                onFreezerToggle: _toggleFreezer,
                                onFridgeToggle: _toggleFridge,
                                onCategoryTap: _onCategoryTap,
                                preferences: FridgePreferencesRepository.current,
                                highlightedCategory: _highlightedCategory,
                              ),
                            ),
                          ),
                          if (FridgeCategoryRepository.isLoading && totalItems == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [AppColors.softShadow],
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Loading your fridge...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutralCharcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Selection Mode Cooking Pan (Clickable surface that zooms into Cooking Workspace)
                if (widget.isSelectionMode) ...[
                  Builder(
                    builder: (context) {
                      final screenWidth = MediaQuery.sizeOf(context).width;
                      final screenHeight = MediaQuery.sizeOf(context).height;

                      // Prominent cooking pan sized to approximately 3x the original visual size (~400px x 216px vs 240px x 130px),
                      // maintaining aspect ratio, full handle visibility, and comfortable vertical margins.
                      final double maxAllowedHeight = (screenHeight * 0.28).clamp(160.0, 228.0);
                      const double shiftRight = 18.0;
                      final double panWidth = (screenWidth - 24.0 - (shiftRight * 2)).clamp(280.0, 400.0).clamp(0.0, maxAllowedHeight / 0.54);
                      final double panHeight = panWidth * 0.54;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.translate(
                              offset: const Offset(shiftRight, 0.0),
                              child: Center(
                                child: Hero(
                                  tag: 'cooking_pan_hero',
                                  flightShuttleBuilder: (
                                    flightContext,
                                    animation,
                                    flightDirection,
                                    fromHeroContext,
                                    toHeroContext,
                                  ) {
                                    final Hero toHero = toHeroContext.widget as Hero;
                                    return Material(
                                      color: Colors.transparent,
                                      child: toHero.child,
                                    );
                                  },
                                  child: CookingPanVisual(
                                    key: _mainPanKey,
                                    panKey: _mainPanKey,
                                    width: panWidth,
                                    height: panHeight,
                                    isCompact: false,
                                    showEmptyGuide: false,
                                    onTap: () => _openCookingWorkspace(context),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _openCookingWorkspace(context),
                              child: Text(
                                selectedCount > 0
                                    ? '$selectedCount ingredient${selectedCount > 1 ? 's' : ''} in pan · Tap to open'
                                    : 'Your pan is ready · Tap ingredients to cook',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
