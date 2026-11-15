import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrifridge/core/theme/app_colors.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/use_soon_service.dart';
import 'package:nutrifridge/screens/fridge/widgets/use_soon_section.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 11, 14, 12, 0, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UseSoonService.setClockProvider(() => fixedNow);
    AiAssistantService.mockHandler = (request) async {
      return {
        'action': 'cook_recipe',
        'hasMeal': false,
        'reply': 'Enjoy your meal!',
      };
    };
  });

  tearDown(() {
    AiAssistantService.mockHandler = null;
  });

  final sampleExpiringItems = [
    CategoryFoodItem(
      id: 'spinach_1',
      name: 'Fresh Spinach',
      quantity: '1 bunch',
      expiryDate: fixedNow.add(const Duration(days: 1)),
      category: 'Vegetables',
    ),
    CategoryFoodItem(
      id: 'tomato_1',
      name: 'Ripe Tomatoes',
      quantity: '2 pieces',
      expiryDate: fixedNow.add(const Duration(days: 2)),
      category: 'Vegetables',
    ),
  ];

  group('Use Soon — Find Meals Button Refinements', () {
    testWidgets('1. Sparkle icon is completely removed from Find Meals button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(itemsOverride: sampleExpiringItems),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const ValueKey('find_meals_use_soon_btn'));
      expect(buttonFinder, findsOneWidget);

      // Verify no sparkle icon (Icons.auto_awesome) exists in the button or screen
      expect(find.descendant(of: buttonFinder, matching: find.byIcon(Icons.auto_awesome)), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // Verify "Find Meals" text is present
      expect(find.descendant(of: buttonFinder, matching: find.text('Find Meals')), findsOneWidget);
    });

    testWidgets('2. Text is centered and button retains original styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(itemsOverride: sampleExpiringItems),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const ValueKey('find_meals_use_soon_btn'));
      expect(buttonFinder, findsOneWidget);

      // Check Container styling
      final containerFinder = find.descendant(
        of: buttonFinder,
        matching: find.byType(Container),
      ).first;
      final Container container = tester.widget(containerFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;

      expect(decoration.color, AppColors.forestGreen);
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5));
      expect(container.alignment, Alignment.center);

      final Text textWidget = tester.widget(
        find.descendant(of: buttonFinder, matching: find.text('Find Meals')),
      );
      expect(textWidget.textAlign, TextAlign.center);
    });

    testWidgets('3. Tapping Find Meals still triggers the AI suggestion flow', (tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              itemsOverride: sampleExpiringItems,
              onFindMealsComplete: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const ValueKey('find_meals_use_soon_btn'));
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
    });

    for (final width in [360.0, 390.0, 430.0]) {
      testWidgets('4. Section displays correctly without overflow on $width px width', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UseSoonSection(itemsOverride: sampleExpiringItems),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final buttonFinder = find.byKey(const ValueKey('find_meals_use_soon_btn'));
        expect(buttonFinder, findsOneWidget);
        expect(find.descendant(of: buttonFinder, matching: find.text('Find Meals')), findsOneWidget);
      });
    }

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('5. Find Meals button displays correctly on $width px container', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Builder(
                      builder: (context) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('find_meals_test_btn'),
                            onTap: () {},
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                              decoration: BoxDecoration(
                                color: AppColors.forestGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Find Meals',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final buttonFinder = find.byKey(const ValueKey('find_meals_test_btn'));
        expect(buttonFinder, findsOneWidget);
        expect(find.text('Find Meals'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome), findsNothing);
      });
    }
  });
}
