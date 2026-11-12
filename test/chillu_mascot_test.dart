import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/services/chillu/chillu_sound_controller.dart';
import 'package:nutrifridge/widgets/chillu/chillu_animation_controller.dart';
import 'package:nutrifridge/widgets/chillu/chillu_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChilluAnimationController Tests', () {
    test('Initial state is idle and celebration jump is false', () {
      final controller = ChilluAnimationController();
      expect(controller.state, ChilluState.idle);
      expect(controller.isCelebrationJump, isFalse);
      expect(controller.isProcessing, isFalse);
      controller.dispose();
    });

    test('Celebration jump is true only for recipeFound and mealLogged', () {
      final controller = ChilluAnimationController();

      controller.recipeFound();
      expect(controller.state, ChilluState.recipeFound);
      expect(controller.isCelebrationJump, isTrue);

      controller.mealLogged();
      expect(controller.state, ChilluState.mealLogged);
      expect(controller.isCelebrationJump, isTrue);

      controller.idle();
      expect(controller.state, ChilluState.idle);
      expect(controller.isCelebrationJump, isFalse);

      controller.process();
      expect(controller.state, ChilluState.processing);
      expect(controller.isCelebrationJump, isFalse);
      expect(controller.isProcessing, isTrue);

      controller.dispose();
    });

    test('Transient states auto-reset back to idle after duration', () async {
      final controller = ChilluAnimationController();

      controller.triggerState(ChilluState.greeting, duration: const Duration(milliseconds: 50));
      expect(controller.state, ChilluState.greeting);

      await Future.delayed(const Duration(milliseconds: 80));
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    test('Attentive, listening, and thinking are persistent until explicitly transitioned', () async {
      final controller = ChilluAnimationController();

      controller.attentive();
      expect(controller.state, ChilluState.attentive);
      await Future.delayed(const Duration(milliseconds: 60));
      // Does not auto-reset
      expect(controller.state, ChilluState.attentive);

      controller.listening();
      expect(controller.state, ChilluState.listening);
      await Future.delayed(const Duration(milliseconds: 60));
      expect(controller.state, ChilluState.listening);

      controller.think();
      expect(controller.state, ChilluState.thinking);
      await Future.delayed(const Duration(milliseconds: 60));
      expect(controller.state, ChilluState.thinking);

      controller.idle();
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    test('State flow: idle -> attentive -> listening -> thinking -> idle', () {
      final controller = ChilluAnimationController();

      expect(controller.state, ChilluState.idle);

      // User focuses input / types
      controller.attentive();
      expect(controller.state, ChilluState.attentive);

      // Voice recording starts
      controller.listening();
      expect(controller.state, ChilluState.listening);

      // Recording ends, message submitted
      controller.think();
      expect(controller.state, ChilluState.thinking);

      // Response received
      controller.idle();
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });
  });

  group('ChilluSoundController Tests', () {
    test('Sound on/off toggle and preference notification', () async {
      final soundCtrl = ChilluSoundController.instance;

      await soundCtrl.setSoundEnabled(false);
      expect(soundCtrl.isSoundEnabled, isFalse);
      expect(soundCtrl.soundEnabledNotifier.value, isFalse);

      await soundCtrl.toggleSound();
      expect(soundCtrl.isSoundEnabled, isTrue);
      expect(soundCtrl.soundEnabledNotifier.value, isTrue);
    });

    test('Greeting chirp plays only once per session', () async {
      final soundCtrl = ChilluSoundController.instance;
      soundCtrl.resetSession();
      expect(soundCtrl.hasGreetedThisSession, isFalse);

      await soundCtrl.playGreetingChirp();
      expect(soundCtrl.hasGreetedThisSession, isTrue);

      // Subsequent call does not reset session flag
      await soundCtrl.playGreetingChirp();
      expect(soundCtrl.hasGreetedThisSession, isTrue);
    });
  });

  group('ChilluMascot Widget Rendering Tests', () {
    testWidgets('Renders master PNG in idle state', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 100,
            ),
          ),
        ),
      );

      // Verify that master asset is loaded
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsWidgets);

      final images = tester.widgetList<Image>(imageFinder);
      for (final image in images) {
        expect((image.image as AssetImage).assetName, ChilluMascot.masterAsset);
      }

      controller.dispose();
    });

    testWidgets('Switches to joyful jump GIF during celebration states', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 100,
            ),
          ),
        ),
      );

      // Trigger recipe found
      controller.recipeFound();
      await tester.pump();

      final gifImage = tester.widget<Image>(find.byType(Image));
      expect((gifImage.image as AssetImage).assetName, ChilluMascot.joyfulJumpAsset);

      // Return to idle
      controller.idle();
      await tester.pump();

      final idleImage = tester.widget<Image>(find.byType(Image).first);
      expect((idleImage.image as AssetImage).assetName, ChilluMascot.masterAsset);

      controller.dispose();
    });

    testWidgets('Respects reduced motion accessibility preference', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: ChilluMascot(
                controller: controller,
                size: 100,
              ),
            ),
          ),
        ),
      );

      // In reduced motion, displays static master PNG directly
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, ChilluMascot.masterAsset);

      controller.dispose();
    });

    testWidgets('Tapping mascot triggers greeting reaction', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 100,
            ),
          ),
        ),
      );

      expect(controller.state, ChilluState.idle);
      await tester.tap(find.byType(ChilluMascot));
      await tester.pump();

      expect(controller.state, ChilluState.greeting);

      controller.dispose();
    });

    testWidgets('Renders seamlessly across attentive, listening, and thinking states', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 100,
            ),
          ),
        ),
      );

      // 1. Attentive state
      controller.attentive();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state, ChilluState.attentive);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // 2. Listening state
      controller.listening();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state, ChilluState.listening);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // 3. Thinking state
      controller.think();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state, ChilluState.thinking);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // 4. Return to Idle
      controller.idle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state, ChilluState.idle);
      expect(find.byType(ChilluMascot), findsOneWidget);

      controller.dispose();
    });
  });
}
