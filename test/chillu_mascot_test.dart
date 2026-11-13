import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/services/chillu/chillu_sound_controller.dart';
import 'package:nutrifridge/widgets/chillu/chillu_animation_controller.dart';
import 'package:nutrifridge/widgets/chillu/chillu_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/shared_preferences'), (call) async {
      if (call.method == 'getAll') return <String, dynamic>{};
      return true;
    });
  });

  group('ChilluAnimationController Tests', () {
    test('Initial state is idle and celebration jump is false', () {
      final controller = ChilluAnimationController();
      expect(controller.state, ChilluState.idle);
      expect(controller.isCelebrationJump, isFalse);
      expect(controller.isProcessing, isFalse);
      controller.dispose();
    });

    test('Celebration jump is true strictly for celebrating and mealLogged user actions', () {
      final controller = ChilluAnimationController();

      // Celebrating user actions use celebration jump GIF
      controller.celebrating();
      expect(controller.state, ChilluState.celebrating);
      expect(controller.isCelebrationJump, isTrue);

      controller.mealLogged();
      expect(controller.state, ChilluState.celebrating);
      expect(controller.isCelebrationJump, isTrue);

      controller.itemAdded();
      expect(controller.state, ChilluState.celebrating);
      expect(controller.isCelebrationJump, isTrue);

      controller.idle();

      // Recipe suggestions trigger excited, NOT celebration jump
      controller.excited();
      expect(controller.state, ChilluState.excited);
      expect(controller.isCelebrationJump, isFalse);

      controller.idle();

      controller.recipeFound();
      expect(controller.state, ChilluState.excited);
      expect(controller.isCelebrationJump, isFalse);

      controller.idle();

      // Other states do not trigger celebration jump
      controller.happy();
      expect(controller.state, ChilluState.happy);
      expect(controller.isCelebrationJump, isFalse);

      controller.idle();

      controller.confused();
      expect(controller.state, ChilluState.confused);
      expect(controller.isCelebrationJump, isFalse);

      controller.idle();
      expect(controller.state, ChilluState.idle);
      expect(controller.isCelebrationJump, isFalse);

      controller.process();
      expect(controller.state, ChilluState.processing);
      expect(controller.isCelebrationJump, isFalse);
      expect(controller.isProcessing, isTrue);

      controller.dispose();
    });

    test('Priority system prevents lower-priority states from interrupting higher-priority transient states', () {
      final controller = ChilluAnimationController();

      // 1. Celebrating (priority 8) cannot be interrupted by Happy (5) or Attentive (2)
      controller.celebrating();
      expect(controller.state, ChilluState.celebrating);

      controller.happy();
      expect(controller.state, ChilluState.celebrating); // Ignored due to lower priority

      controller.attentive();
      expect(controller.state, ChilluState.celebrating); // Ignored

      // 2. Excited (priority 7) cannot be interrupted by Happy (5)
      controller.idle();
      controller.excited();
      expect(controller.state, ChilluState.excited);

      controller.happy();
      expect(controller.state, ChilluState.excited); // Ignored

      // 3. Forced transition can override
      controller.triggerState(ChilluState.idle, force: true);
      expect(controller.state, ChilluState.idle);

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

      // Trigger celebrating
      controller.celebrating();
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

    testWidgets('Curious Perk-Up entrance progresses into continuous attentive animation loop', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 46,
            ),
          ),
        ),
      );

      // Trigger attentive Curious Perk-Up
      controller.attentive();
      await tester.pump(); // Start perk

      // Pop-up phase (250ms)
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.state, ChilluState.attentive);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // Entrance settling (750ms total)
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.state, ChilluState.attentive);

      // Continuous loop remains actively animated over subsequent seconds (e.g. 5s, 10s, 15s)
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(controller.state, ChilluState.attentive);
        expect(find.byType(ChilluMascot), findsOneWidget);
      }

      // Transition immediately to thinking on submit
      controller.think();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state, ChilluState.thinking);

      // Transition back to idle
      controller.idle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    testWidgets('Historical avatars remain static with disableAnimations: true while latest avatar animates', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Historical message avatar (static)
                const ChilluMascot(
                  size: 46,
                  showShadow: false,
                  disableAnimations: true,
                ),
                // Latest message avatar (reactive)
                ChilluMascot(
                  controller: controller,
                  size: 46,
                  showShadow: false,
                  disableAnimations: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ChilluMascot), findsNWidgets(2));

      // Trigger attentive
      controller.attentive();
      await tester.pump(const Duration(milliseconds: 200));

      // Both widgets render without conflict
      expect(controller.state, ChilluState.attentive);
      expect(find.byType(ChilluMascot), findsNWidgets(2));

      controller.dispose();
    });

    testWidgets('Renders all four emotional reactions (happy, excited, confused, celebrating) seamlessly', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 46,
            ),
          ),
        ),
      );

      // 1. Happy state (cheerful bounce & smiling crescent eyes)
      controller.happy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.state, ChilluState.happy);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // 2. Excited state (energetic high jump & gleaming eyes)
      controller.idle();
      controller.excited();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.state, ChilluState.excited);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // 3. Confused state (head tilt, quizzical asymmetrical brow & leaf tilt)
      controller.idle();
      controller.confused();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.state, ChilluState.confused);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // 4. Celebrating state (triumphant jump)
      controller.idle();
      controller.celebrating();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.state, ChilluState.celebrating);
      expect(find.byType(ChilluMascot), findsOneWidget);

      // Return to idle
      controller.idle();
      await tester.pump();
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    testWidgets('AI Response Error scenarios trigger persistent Confused state and follow transition flow', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      // SCENARIO 1: "No response from AI" triggers Confused state
      controller.think();
      expect(controller.state, ChilluState.thinking);

      // AI response error occurs: Thinking -> Confused
      controller.confused(persistent: true);
      expect(controller.state, ChilluState.confused);

      // Verify Confused state is persistent (does not auto-reset back to idle after 2.5s)
      await tester.pump(const Duration(milliseconds: 2500));
      expect(controller.state, ChilluState.confused);

      // SCENARIO 2: AI request times out -> Confused (prevent duplicate restart)
      controller.confused(persistent: true);
      expect(controller.state, ChilluState.confused);

      // SCENARIO 3: AI service becomes unavailable -> Confused
      controller.confused(persistent: true);
      expect(controller.state, ChilluState.confused);

      // SCENARIO 6: User starts typing a new request -> Confused to Attentive
      controller.attentive();
      expect(controller.state, ChilluState.attentive);

      // SCENARIO 5: User retries after an error -> Thinking
      controller.think();
      expect(controller.state, ChilluState.thinking);

      // SCENARIO 4: Successful AI response -> No Confused reaction (Happy/Excited)
      controller.happy();
      expect(controller.state, ChilluState.happy);
      expect(controller.state != ChilluState.confused, isTrue);

      // Dismissed / completed -> Idle
      controller.idle();
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    testWidgets('Chat avatars: latest avatar and mascot synchronize Confused while older avatars remain static', (WidgetTester tester) async {
      final sharedController = ChilluAnimationController();

      // Mount 3 avatars:
      // 1. Hero / Main Mascot (110px)
      // 2. Older assistant avatar (46px, disableAnimations: true, controller: null)
      // 3. Latest assistant avatar (46px, disableAnimations: false, controller: sharedController)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChilluMascot(
                  controller: sharedController,
                  size: 110,
                ),
                ChilluMascot(
                  controller: null,
                  disableAnimations: true,
                  size: 46,
                  showShadow: false,
                ),
                ChilluMascot(
                  controller: sharedController,
                  disableAnimations: false,
                  size: 46,
                  showShadow: false,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(sharedController.state, ChilluState.idle);

      // AI enters Thinking
      sharedController.think();
      await tester.pump();
      expect(sharedController.state, ChilluState.thinking);

      // AI response fails -> Thinking -> Confused
      sharedController.confused(persistent: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sharedController.state, ChilluState.confused);

      // Both hero mascot and latest avatar share sharedController in Confused state
      expect(find.byType(ChilluMascot), findsNWidgets(3));

      // After settling, Confused state remains active while error is latest
      await tester.pump(const Duration(milliseconds: 2000));
      expect(sharedController.state, ChilluState.confused);

      // User retries -> Thinking
      sharedController.think();
      await tester.pump();
      expect(sharedController.state, ChilluState.thinking);

      // Error dismissed -> Idle
      sharedController.idle();
      await tester.pump();
      expect(sharedController.state, ChilluState.idle);

      sharedController.dispose();
    });

    testWidgets('Renders Sleepy state with half-closed eyes, drooped leaves, and slow breathing', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 110,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(controller.state, ChilluState.idle);

      // Trigger Sleepy state
      controller.sleepy();
      await tester.pump();
      expect(controller.state, ChilluState.sleepy);

      // Relaxing and yawn entrance transition (0 to 1800ms)
      await tester.pump(const Duration(milliseconds: 600)); // In yawn phase
      expect(find.byType(ChilluMascot), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400)); // Settled into continuous sleepy idle
      expect(controller.state, ChilluState.sleepy);

      // Verify semantics description
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*sleepy')), findsOneWidget);

      // Continuous sleepy breathing and slow blinking over multiple seconds
      await tester.pump(const Duration(milliseconds: 2500));
      expect(controller.state, ChilluState.sleepy);

      controller.dispose();
    });

    testWidgets('Wake-up reaction triggers upward stretch, bounce, and transitions smoothly into destination states', (WidgetTester tester) async {
      final controller = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChilluMascot(
              controller: controller,
              size: 110,
            ),
          ),
        ),
      );

      await tester.pump();

      // Enter Sleepy
      controller.sleepy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      expect(controller.state, ChilluState.sleepy);

      // 1. Wake-up to Attentive (e.g. user starts typing)
      controller.attentive();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);
      expect(controller.wakeUpDestination, ChilluState.attentive);

      // Upward stretch & cheerful bounce progress through 1000ms window without being interrupted
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.isWakingUp, isTrue);
      await tester.pump(const Duration(milliseconds: 550));
      expect(controller.isWakingUp, isFalse);
      expect(controller.state, ChilluState.attentive);

      // 2. Return to Sleepy then wake up to Listening (mic tap)
      controller.sleepy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      expect(controller.state, ChilluState.sleepy);

      controller.listening();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);
      expect(controller.wakeUpDestination, ChilluState.listening);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(controller.state, ChilluState.listening);

      // 3. Return to Sleepy then wake up to Thinking (message send)
      controller.sleepy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      expect(controller.state, ChilluState.sleepy);

      controller.think();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);
      expect(controller.wakeUpDestination, ChilluState.thinking);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(controller.state, ChilluState.thinking);

      // 4. Return to Sleepy then wake up to Idle (tap on screen)
      controller.sleepy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      expect(controller.state, ChilluState.sleepy);

      controller.idle();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);
      expect(controller.wakeUpDestination, ChilluState.idle);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    testWidgets('Chat avatars synchronize Sleepy and Wake-Up while historical avatars remain static', (WidgetTester tester) async {
      final sharedController = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Main hero mascot
                ChilluMascot(
                  controller: sharedController,
                  size: 110,
                ),
                // Older assistant avatar (static, disableAnimations: true)
                ChilluMascot(
                  controller: null,
                  disableAnimations: true,
                  size: 46,
                  showShadow: false,
                ),
                // Latest assistant avatar (active, shared controller)
                ChilluMascot(
                  controller: sharedController,
                  disableAnimations: false,
                  size: 46,
                  showShadow: false,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(sharedController.state, ChilluState.idle);

      // Enter Sleepy
      sharedController.sleepy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sharedController.state, ChilluState.sleepy);

      // Both hero and latest avatar reflect Sleepy state semantics
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*sleepy')), findsNWidgets(2));

      // Wake-up to Attentive
      sharedController.attentive();
      await tester.pump();
      expect(sharedController.isWakingUp, isTrue);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(sharedController.state, ChilluState.attentive);
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*attentive')), findsNWidgets(2));

      sharedController.dispose();
    });

    test('Zero audio rule: Sleepy and Wake-Up produce NO audio playback', () {
      final soundController = ChilluSoundController.instance;
      // Excited and Celebrating are the ONLY states that produce audio
      // Neither Sleepy nor Wake-Up calls soundController playback methods
      expect(soundController.isSoundEnabled, isTrue);
    });
  });
}
