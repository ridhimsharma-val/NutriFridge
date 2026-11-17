import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/screens/profile/profile_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_profile_user';
    GroceryService.instance.mockSupabaseTable = {
      'grocery_items': <Map<String, dynamic>>[],
      'fridge_items': <Map<String, dynamic>>[],
    };
    await GroceryService.instance.initialize();
  });

  testWidgets('Profile page displays Grocery List card below Saved Recipes and navigates to GroceryListScreen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Saved Recipes tile exists
    final savedRecipesFinder = find.byKey(const ValueKey('profile_saved_recipes_tile'));
    expect(savedRecipesFinder, findsOneWidget);

    // Verify Grocery List tile exists below Saved Recipes
    final groceryListFinder = find.byKey(const ValueKey('profile_grocery_list_tile'));
    expect(groceryListFinder, findsOneWidget);

    // Check vertical positioning: grocery list tile is below saved recipes tile
    final savedRect = tester.getRect(savedRecipesFinder);
    final groceryRect = tester.getRect(groceryListFinder);
    expect(groceryRect.top, greaterThan(savedRect.bottom));

    // Check title and subtitle
    expect(find.text('Grocery List'), findsOneWidget);
    expect(find.text('No items on your list'), findsOneWidget);

    // Add item and check subtitle updates reactively
    await GroceryService.instance.addItem(name: 'Apples', category: 'Fruits');
    await tester.pumpAndSettle();
    expect(find.text('1 item to buy'), findsOneWidget);

    // Tap Grocery List card and verify navigation to GroceryListScreen
    await tester.tap(groceryListFinder);
    await tester.pumpAndSettle();

    expect(find.byType(GroceryListScreen), findsOneWidget);
  });
}
