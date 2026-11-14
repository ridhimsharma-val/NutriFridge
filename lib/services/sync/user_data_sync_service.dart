import '../../models/nutrition_data.dart';
import '../../screens/fridge/models/category_item.dart';
import '../../screens/fridge/models/fridge_preferences.dart';
import '../recipe/saved_recipes_service.dart';

/// Central coordinator to load or clear user-scoped state upon login,
/// session restoration, or logout.
class UserDataSyncService {
  static final UserDataSyncService instance = UserDataSyncService();

  static String? _activeUserId;

  static String? get activeUserId => _activeUserId;

  /// Loads all user-scoped data (inventory, preferences, profile, nutrition goals, saved recipes)
  /// for the authenticated user.
  static Future<void> syncAllUserData(String userId, {bool force = false}) async {
    _activeUserId = userId;

    await Future.wait([
      FridgeCategoryRepository.loadFromSupabase(userId: userId, force: force),
      FridgePreferencesRepository.loadFromSupabase(userId: userId),
      MockDataRepository.loadFromSupabase(userId: userId),
      SavedRecipesService.instance.init(userId: userId, forceReload: force),
    ]);

    // Automatically and safely synchronize any recipes bookmarked while offline or prior to auth
    await SavedRecipesService.instance.syncLocalRecipesToSupabase(targetUserId: userId);
  }

  /// Clears in-memory caches and resets repositories to prevent data bleeding across accounts.
  static void clearAllUserDataForLogout() {
    _activeUserId = null;
    FridgeCategoryRepository.clearForLogout();
    FridgePreferencesRepository.reset();
    MockDataRepository.reset();
    SavedRecipesService.instance.clearForLogout();
  }

  /// Instance forwarding for convenience and compatibility
  Future<void> syncUser(String userId, {bool force = false}) => syncAllUserData(userId, force: force);
  void clearForLogout() => clearAllUserDataForLogout();
}
