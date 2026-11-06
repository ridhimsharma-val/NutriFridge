import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/models/fridge_preferences.dart';
import 'package:nutrifridge/screens/profile/models/user_profile_data.dart';
import 'package:nutrifridge/services/inventory/fridge_inventory_repository.dart';
import 'package:nutrifridge/services/preferences/fridge_preferences_service.dart';
import 'package:nutrifridge/services/profile/profile_service.dart';
import 'package:nutrifridge/services/sync/user_data_sync_service.dart';

void main() {
  group('FridgeInventoryRepository Mapping & Validation Tests', () {
    test('formatDate and parseDate round-trip ISO YYYY-MM-DD cleanly', () {
      final date = DateTime(2026, 11, 15);
      final formatted = FridgeInventoryRepository.formatDate(date);
      expect(formatted, '2026-11-15');

      final parsed = FridgeInventoryRepository.parseDate(formatted);
      expect(parsed?.year, 2026);
      expect(parsed?.month, 11);
      expect(parsed?.day, 15);
    });

    test('buildInsertRow formats insert map for Supabase correctly', () {
      final targetDate = DateTime(2026, 11, 20);
      final row = FridgeInventoryRepository.buildInsertRow(
        userId: 'test-user-uuid-123',
        name: 'Whole Milk',
        category: 'dairy products',
        quantity: 2.5,
        unit: 'L',
        expiryDate: targetDate,
        storageImagePath: 'user_items/milk.jpg',
      );

      expect(row['user_id'], 'test-user-uuid-123');
      expect(row['name'], 'Whole Milk');
      expect(row['category'], 'Dairy Products');
      expect(row['quantity'], 2.5);
      expect(row['unit'], 'L');
      expect(row['expiry_date'], '2026-11-20');
      expect(row['storage_image_path'], 'user_items/milk.jpg');
    });

    test('mapRowToItem correctly converts database record to CategoryFoodItem', () {
      final row = {
        'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
        'name': 'Greek Yogurt',
        'category': 'DAIRY PRODUCTS',
        'quantity': 500,
        'unit': 'g',
        'expiry_date': '2026-11-25',
        'storage_image_path': 'storage/yogurt.png',
      };

      final item = FridgeInventoryRepository.mapRowToItem(row);
      expect(item.id, 'd290f1ee-6c54-4b01-90e6-d701748f0851');
      expect(item.name, 'Greek Yogurt');
      expect(item.category, 'DAIRY PRODUCTS');
      expect(item.quantity, '500 g');
      expect(item.storageImagePath, 'storage/yogurt.png');
      expect(item.expiryDate, isNotNull);
      expect(item.expiryDate!.year, 2026);
      expect(item.expiryDate!.month, 11);
      expect(item.expiryDate!.day, 25);
    });

    test('buildInsertRow validates against empty names and negative quantities', () {
      expect(
        () => FridgeInventoryRepository.buildInsertRow(
          userId: 'user-1',
          name: '',
          category: 'FRESH VEGETABLES',
          quantity: 2,
          unit: 'pieces',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => FridgeInventoryRepository.buildInsertRow(
          userId: 'user-1',
          name: 'Carrot',
          category: 'FRESH VEGETABLES',
          quantity: -1,
          unit: 'pieces',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Dynamic expiryDays calculates correctly from expiryDate', () {
      final today = DateTime.now();
      final targetDate = DateTime(today.year, today.month, today.day + 7);
      final item = CategoryFoodItem(
        id: 'dynamic-test-id',
        name: 'Almond Milk',
        quantity: '1 L',
        expiryDate: targetDate,
      );

      expect(item.expiryDays, 7);
    });
  });

  group('FridgePreferencesService Mapping Tests', () {
    test('toPreferencesMap serializes exterior_color and freezer_position', () {
      const prefs = FridgePreferences(
        exteriorColor: FridgeColorFinish.matteBlack,
        freezerPosition: FreezerPosition.bottom,
      );

      final map = FridgePreferencesService.toPreferencesMap(prefs, userId: 'user-123');
      expect(map['user_id'], 'user-123');
      expect(map['exterior_color'], 'matteBlack');
      expect(map['freezer_position'], 'bottom');
    });

    test('fromPreferencesMap parses row and handles unknown or null values safely', () {
      final prefs1 = FridgePreferencesService.fromPreferencesMap({
        'exterior_color': 'sageGreen',
        'freezer_position': 'top',
      });
      expect(prefs1.exteriorColor, FridgeColorFinish.sageGreen);
      expect(prefs1.freezerPosition, FreezerPosition.top);

      final prefsDefault = FridgePreferencesService.fromPreferencesMap({
        'exterior_color': 'unknown_color',
        'freezer_position': null,
      });
      expect(prefsDefault.exteriorColor, FridgeColorFinish.midnightNavy);
      expect(prefsDefault.freezerPosition, FreezerPosition.top);
    });
  });

  group('ProfileService Mapping & Validation Tests', () {
    test('toProfileMap and mapDatabaseToProfile roundtrip profile settings', () {
      const profile = UserProfileData(
        displayName: 'Master Chef',
        dietaryPreference: 'Vegetarian',
        nutritionGoal: 'Increase protein intake',
        dailyCalorieTarget: 2200,
        allergies: {'Peanuts'},
        avoidedFoods: {'Refined sugar'},
        customRestrictions: ['Low Sodium'],
        mealRemindersEnabled: true,
        expiryAlertsEnabled: false,
      );

      final profileMap = ProfileService.toProfileMap(profile);
      expect(profileMap['display_name'], 'Master Chef');
      expect(profileMap['dietary_preference'], 'Vegetarian');
      expect(profileMap['nutrition_goal'], 'Increase protein intake');
      expect(profileMap['allergies'], contains('Peanuts'));
      expect(profileMap['avoided_foods'], contains('Refined sugar'));
      expect(profileMap['meal_reminders_enabled'], true);
      expect(profileMap['expiry_alerts_enabled'], false);

      final reconstructed = ProfileService.mapDatabaseToProfile(
        profileMap,
        targetCalories: 2200,
      );
      expect(reconstructed.displayName, 'Master Chef');
      expect(reconstructed.dailyCalorieTarget, 2200);
      expect(reconstructed.allergies, contains('Peanuts'));
      expect(reconstructed.mealRemindersEnabled, true);
      expect(reconstructed.expiryAlertsEnabled, false);
    });

    test('toNutritionGoalsMap clamps target_calories to 500-10000 range and enforces non-negative macros', () {
      final goalsLow = ProfileService.toNutritionGoalsMap(
        targetCalories: 200,
        proteinTargetG: 50,
        carbsTargetG: 50,
        fatTargetG: 20,
      );
      expect(goalsLow['target_calories'], 500);

      final goalsHigh = ProfileService.toNutritionGoalsMap(
        targetCalories: 25000,
        proteinTargetG: -10,
        carbsTargetG: -5,
        fatTargetG: 0,
      );
      expect(goalsHigh['target_calories'], 10000);
      expect(goalsHigh['protein_target_g'], 0);
      expect(goalsHigh['carbs_target_g'], 0);
      expect(goalsHigh['fat_target_g'], 0);
    });
  });

  group('UserDataSyncService & Session Isolation Tests', () {
    test('clearAllUserDataForLogout wipes cached state across all repositories', () {
      // Modify in-memory state
      FridgePreferencesRepository.update(
        const FridgePreferences(
          exteriorColor: FridgeColorFinish.sageGreen,
          freezerPosition: FreezerPosition.bottom,
        ),
      );
      MockDataRepository.updateProfile(
        MockDataRepository.profile.copyWith(displayName: 'Session Chef'),
      );

      expect(FridgePreferencesRepository.current.exteriorColor, FridgeColorFinish.sageGreen);
      expect(MockDataRepository.profile.displayName, 'Session Chef');

      // Clear for logout
      UserDataSyncService.clearAllUserDataForLogout();

      // State is reset to clean defaults
      expect(FridgePreferencesRepository.current.exteriorColor, FridgeColorFinish.midnightNavy);
      expect(UserDataSyncService.activeUserId, isNull);
    });
  });
}
