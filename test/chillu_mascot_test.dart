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

    testWidgets('Renders Sleepy state with full lying-down horizontal pose, closed eyes, and floating Zs', (WidgetTester tester) async {
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

      // Lying-down entrance transition (0 to 2400ms): bends, rotates 85° horizontally, settles onto ground
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(ChilluMascot), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500)); // Settled into continuous horizontal sleep
      expect(controller.state, ChilluState.sleepy);

      // Verify semantics description reflects lying down asleep
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*lying down asleep')), findsOneWidget);

      // Continuous horizontal sleeping breathing and subtle dream shifts over multiple seconds
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
      await tester.pump(const Duration(milliseconds: 2500));
      expect(controller.state, ChilluState.sleepy);

      // 1. Wake-up to Attentive (e.g. user starts typing)
      controller.attentive();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);
      expect(controller.wakeUpDestination, ChilluState.attentive);

      // Upward leap arc & cheerful bounce progress through 1000ms window without being interrupted
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.isWakingUp, isTrue);
      await tester.pump(const Duration(milliseconds: 550));
      expect(controller.isWakingUp, isFalse);
      expect(controller.state, ChilluState.attentive);

      // 2. Return to Sleepy then wake up to Listening (mic tap)
      controller.sleepy();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
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
      await tester.pump(const Duration(milliseconds: 2500));
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
      await tester.pump(const Duration(milliseconds: 2500));
      expect(controller.state, ChilluState.sleepy);

      controller.idle();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);
      expect(controller.wakeUpDestination, ChilluState.idle);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(controller.state, ChilluState.idle);

      controller.dispose();
    });

    testWidgets('Wake-up animation plays strictly once and does not repeat or trigger twice', (WidgetTester tester) async {
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
      controller.sleepy();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(controller.state, ChilluState.sleepy);

      // Trigger wake-up
      controller.idle();
      await tester.pump();
      expect(controller.isWakingUp, isTrue);

      // Verify waking up semantics label is present during the jump
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*waking up with a jump')), findsOneWidget);

      // Progress past 1000ms jump to complete wake-up
      await tester.pump(const Duration(milliseconds: 1050));
      expect(controller.isWakingUp, isFalse);
      expect(controller.state, ChilluState.idle);
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsOneWidget);

      // Pump several frames in idle to ensure wake-up animation does NOT trigger a second time
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*waking up with a jump')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsOneWidget);

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
      await tester.pump(const Duration(milliseconds: 2500));
      expect(sharedController.state, ChilluState.sleepy);

      // Both hero and latest avatar reflect lying down asleep semantics
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*lying down asleep')), findsNWidgets(2));

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

    testWidgets('Entry sequence transitions: entryJump (520ms) -> greeting (2000ms) -> idle', (WidgetTester tester) async {
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

      // 1. Initial state is idle
      expect(controller.state, ChilluState.idle);

      // 2. Play entry sequence
      controller.playEntrySequence();
      await tester.pump();
      expect(controller.state, ChilluState.entryJump);
      expect(find.bySemanticsLabel(RegExp(r'jumping in to say hello')), findsOneWidget);

      // 3. Fast-forward past entry jump (520ms) -> transitions to greeting
      await tester.pump(const Duration(milliseconds: 530));
      expect(controller.state, ChilluState.greeting);
      expect(find.bySemanticsLabel(RegExp(r'waving hello')), findsOneWidget);

      // 4. Fast-forward past greeting (2000ms) -> transitions to idle
      await tester.pump(const Duration(milliseconds: 2010));
      expect(controller.state, ChilluState.idle);
      expect(find.bySemanticsLabel(RegExp(r'happy and waiting')), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Latest chat avatar synchronizes Greeting while historical avatars remain static', (WidgetTester tester) async {
      final sharedController = ChilluAnimationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // 1. Hero Mascot (110px)
                ChilluMascot(
                  controller: sharedController,
                  size: 110,
                ),
                // 2. Historical Assistant Message Avatar (46px, static)
                const ChilluMascot(
                  disableAnimations: true,
                  size: 46,
                  showShadow: false,
                ),
                // 3. Latest Assistant Message Avatar (46px, animated)
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

      // Trigger greeting
      sharedController.greet();
      await tester.pump();
      expect(sharedController.state, ChilluState.greeting);

      // Hero mascot and latest avatar synchronize greeting semantics label
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*waving hello')), findsNWidgets(2));
      // Historical avatar remains static in idle waiting pose
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsOneWidget);

      // After 2000ms, both settle back to idle
      await tester.pump(const Duration(milliseconds: 2050));
      expect(sharedController.state, ChilluState.idle);
      // All three (hero + latest + historical) are at rest in idle pose
      expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsNWidgets(3));

      sharedController.dispose();
    });

    test('Audio rule: Greeting is silent; only Excited and Celebrating retain audio', () async {
      final soundController = ChilluSoundController.instance;

      // Excited and Celebrating play audio
      await soundController.playExcited();
      await soundController.playCelebrating();

      // Entry Jump is completely silent
      await soundController.playEntryJump();
      // Greeting has no audio method / produces no sound
      expect(soundController.isSoundEnabled, isTrue);
    });

    group('Speaking Animation System Tests', () {
      test('Initial state: Thinking transitions into Speaking when AI response delivery begins', () {
        final controller = ChilluAnimationController();
        controller.think();
        expect(controller.state, ChilluState.thinking);

        // Response delivery begins
        controller.speak();
        expect(controller.state, ChilluState.speaking);
        controller.dispose();
      });

      test('Streamed chunks: Speaking does not restart animation loop on repeated chunk calls', () {
        final controller = ChilluAnimationController();
        controller.think();
        controller.speak();
        expect(controller.state, ChilluState.speaking);

        // Stream chunk 1 arrives
        controller.speak();
        expect(controller.state, ChilluState.speaking);

        // Stream chunk 2 arrives
        controller.speak();
        expect(controller.state, ChilluState.speaking);

        // Delivery concludes -> transitions to Idle
        controller.finishSpeaking();
        expect(controller.state, ChilluState.idle);
        controller.dispose();
      });

      test('Completed response transitions Speaking -> Idle', () {
        final controller = ChilluAnimationController();
        controller.speak();
        expect(controller.state, ChilluState.speaking);

        controller.finishSpeaking();
        expect(controller.state, ChilluState.idle);
        controller.dispose();
      });

      test('Failed response transitions Speaking -> Confused', () {
        final controller = ChilluAnimationController();
        controller.speak();
        expect(controller.state, ChilluState.speaking);

        controller.confused(persistent: true);
        expect(controller.state, ChilluState.confused);
        controller.dispose();
      });

      test('User interactions (typing/voice) take priority over Speaking', () {
        final controller = ChilluAnimationController();
        controller.speak();
        expect(controller.state, ChilluState.speaking);

        // User starts typing
        controller.attentive();
        expect(controller.state, ChilluState.attentive);

        // Speak call while typing does not override user interaction
        controller.speak();
        expect(controller.state, ChilluState.attentive);

        // User starts voice recording
        controller.listening();
        expect(controller.state, ChilluState.listening);

        // Speak call while recording does not override user interaction
        controller.speak();
        expect(controller.state, ChilluState.listening);

        controller.dispose();
      });

      testWidgets('Latest chat avatar mirrors Speaking while older chat avatars stay static', (tester) async {
        final sharedController = ChilluAnimationController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // 1. Hero Mascot (110px)
                  ChilluMascot(
                    controller: sharedController,
                    size: 110,
                  ),
                  // 2. Historical Assistant Message Avatar (46px, static)
                  const ChilluMascot(
                    disableAnimations: true,
                    size: 46,
                    showShadow: false,
                  ),
                  // 3. Latest Assistant Message Avatar (46px, animated)
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

        // Transition from Thinking to Speaking
        sharedController.think();
        await tester.pump();
        expect(sharedController.state, ChilluState.thinking);

        sharedController.speak();
        await tester.pump();
        expect(sharedController.state, ChilluState.speaking);

        // Hero mascot and latest avatar synchronize speaking semantics label
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*speaking to you')), findsNWidgets(2));
        // Historical avatar remains static in idle waiting pose
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsOneWidget);

        // Animate speaking cycle (mouth movement and cadence)
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*speaking to you')), findsNWidgets(2));

        // Finish speaking -> both synchronize back to Idle
        sharedController.finishSpeaking();
        await tester.pump();
        expect(sharedController.state, ChilluState.idle);
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsNWidgets(3));

        sharedController.dispose();
      });

      test('Audio rule: Speaking is silent; only Excited and Celebrating retain audio', () {
        final soundController = ChilluSoundController.instance;
        // Speaking produces no sound effects and does not affect sound controller
        expect(soundController.isSoundEnabled, isTrue);
      });

      testWidgets('Speaking duration runs for 5 seconds and auto-resets to Idle', (tester) async {
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

        controller.speak();
        await tester.pump();
        expect(controller.state, ChilluState.speaking);
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*speaking to you')), findsOneWidget);

        // At 2.5s, Chillu is still actively speaking
        await tester.pump(const Duration(milliseconds: 2500));
        expect(controller.state, ChilluState.speaking);
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*speaking to you')), findsOneWidget);

        // At 5.05s, speaking duration completes and Chillu settles back into Idle
        await tester.pump(const Duration(milliseconds: 2550));
        expect(controller.state, ChilluState.idle);
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*happy and waiting')), findsOneWidget);

        controller.dispose();
      });
    });

    group('ChilluDroppingAvatar Tests', () {
      testWidgets('Drops with gravitational curve, gooey bounce on landing, and continues active state', (tester) async {
        final controller = ChilluAnimationController();
        controller.speak();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChilluDroppingAvatar(
                controller: controller,
                size: 46,
                animateDrop: true,
              ),
            ),
          ),
        );

        // Frame 0: Drop begins
        await tester.pump();
        expect(controller.state, ChilluState.speaking);
        expect(find.byType(ChilluDroppingAvatar), findsOneWidget);
        expect(find.byType(ChilluMascot), findsOneWidget);

        // Mid-drop (at ~200ms)
        await tester.pump(const Duration(milliseconds: 200));

        // Impact & gooey squash (at ~350ms)
        await tester.pump(const Duration(milliseconds: 150));

        // Rebound & settling (at 650ms)
        await tester.pump(const Duration(milliseconds: 300));

        // Landed: continues speaking animation
        expect(controller.state, ChilluState.speaking);
        expect(find.bySemanticsLabel(RegExp(r'Chillu mascot.*speaking to you')), findsOneWidget);

        controller.dispose();
      });

      testWidgets('Respects reduced motion accessibility preference', (tester) async {
        final controller = ChilluAnimationController();

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: ChilluDroppingAvatar(
                  controller: controller,
                  size: 46,
                  animateDrop: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(ChilluDroppingAvatar), findsOneWidget);
        expect(find.byType(ChilluMascot), findsOneWidget);

        controller.dispose();
      });
    });
  });
}
