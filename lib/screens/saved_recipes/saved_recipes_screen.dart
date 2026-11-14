import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../../services/food_image/food_image_model.dart';
import '../food_image/widgets/food_image_view.dart';
import '../meal_detail/meal_detail_screen.dart';
import '../../services/recipe/saved_recipes_service.dart';
import 'widgets/recipe_save_button.dart';

/// Dedicated screen displaying bookmarked/saved recipes.
///
/// Supports search by title, category filtering, persistent card rendering,
/// unsaving with immediate removal, and direct navigation to [MealDetailScreen]
/// and Guided Cooking without making any AI or network calls.
class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const List<String> _categories = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
  ];

  @override
  void initState() {
    super.initState();
    SavedRecipesService.instance.init();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecipeRecommendation> _filterRecipes(List<RecipeRecommendation> allRecipes) {
    return allRecipes.where((recipe) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final title = recipe.title.toLowerCase();
        final ingredients = recipe.requiredIngredients.join(' ').toLowerCase();
        if (!title.contains(_searchQuery) && !ingredients.contains(_searchQuery)) {
          return false;
        }
      }

      // 2. Category Filter
      if (_selectedCategory != 'All') {
        final categoryLower = _selectedCategory.toLowerCase();
        final mealTypeLower = recipe.mealType.toLowerCase();
        final tagLower = recipe.tag.toLowerCase();

        final matchesCategory = mealTypeLower.contains(categoryLower) ||
            tagLower.contains(categoryLower) ||
            (categoryLower == 'snacks' && (mealTypeLower.contains('snack') || tagLower.contains('snack')));

        if (!matchesCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: ValueListenableBuilder<List<RecipeRecommendation>>(
          valueListenable: SavedRecipesService.instance.savedRecipesNotifier,
          builder: (context, allSavedRecipes, _) {
            final filteredRecipes = _filterRecipes(allSavedRecipes);

            return CustomScrollView(
              slivers: [
                // Top App Bar
                SliverToBoxAdapter(
                  child: _buildHeader(context, allSavedRecipes.length),
                ),

                // Search & Filter controls (only show if there are saved recipes or an active search)
                if (allSavedRecipes.isNotEmpty || _searchQuery.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: _buildSearchBar(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],

                // Main Content: Empty State or Recipe List
                if (allSavedRecipes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else if (filteredRecipes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoMatchesState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final recipe = filteredRecipes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildRecipeCard(context, recipe),
                          );
                        },
                        childCount: filteredRecipes.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.darkText,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved Recipes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  totalCount == 1 ? '1 saved favourite' : '$totalCount saved favourites',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        key: const ValueKey('saved_recipes_search_input'),
        controller: _searchController,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.darkText,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search saved recipes by name...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.mutedText.withValues(alpha: 0.8),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primaryForest,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.mutedText),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;

          return GestureDetector(
            key: ValueKey('category_chip_$cat'),
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryForest : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryForest
                      : AppColors.cardBorder.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primaryForest.withValues(alpha: 0.2)
                        : const Color(0x06000000),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.darkText,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, RecipeRecommendation recipe) {
    final heroTag = 'saved_recipe_card_${recipe.id}_${recipe.title}';
    final totalTime = recipe.totalTimeMinutes ?? (recipe.prepTimeMinutes + (recipe.cookingTimeMinutes ?? 0));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('saved_recipe_tile_${recipe.id.isNotEmpty ? recipe.id : recipe.title}'),
        onTap: () {
          // Open details screen with pure snapshot without calling Gemini
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MealDetailScreen(
                recommendation: recipe,
                heroTag: heroTag,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe Image Header with Save Button
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Hero(
                        tag: heroTag,
                        child: FoodImageView(
                          name: recipe.title,
                          type: FoodEntityType.recipe,
                          ingredients: recipe.requiredIngredients,
                          fit: BoxFit.cover,
                          fallbackWidget: Container(
                            color: const Color(0xFFF1F6F2),
                            child: const Center(
                              child: Icon(Icons.restaurant_rounded, size: 48, color: AppColors.cardBorder),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Category Pill
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        recipe.mealType.isNotEmpty
                            ? recipe.mealType.toUpperCase()
                            : (recipe.tag.isNotEmpty ? recipe.tag.toUpperCase() : 'RECIPE'),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryForest,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  // Top Right: Unsave / Heart Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: RecipeSaveButton(
                      recipe: recipe,
                      size: 20,
                    ),
                  ),
                ],
              ),

              // Recipe Metadata
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Metrics row: Duration & Calories
                    Row(
                      children: [
                        if (totalTime > 0) ...[
                          const Icon(Icons.access_time_rounded, size: 15, color: AppColors.mutedText),
                          const SizedBox(width: 4),
                          Text(
                            '$totalTime min',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFF97316)),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.calories} kcal',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Cook Mode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryForest,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryForest),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cardBorder.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: 40,
                  color: AppColors.primaryForest,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No saved recipes yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bookmark your favourite AI meal ideas by tapping the heart icon on any recipe. They\'ll be waiting here whenever you\'re ready to cook!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching recipes found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We couldn\'t find any saved recipes for "$_searchQuery" in $_selectedCategory.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedCategory = 'All';
                });
              },
              child: const Text(
                'Reset Filters',
                style: TextStyle(
                  color: AppColors.primaryForest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
