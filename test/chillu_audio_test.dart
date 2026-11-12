import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nutrifridge/services/chillu/chillu_sound_controller.dart';

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

  test('AudioPlayer creates without error and uses assets/ prefix', () {
    final player = AudioPlayer();
    expect(player.audioCache.prefix, 'assets/');
    expect(
      AssetSource('audio/chillu/01_greeting_chirp.wav').path,
      'audio/chillu/01_greeting_chirp.wav',
    );
  });

  test('All eight Chillu sound personality assets exist and are approximately 2 seconds', () {
    final sounds = [
      ChilluSoundController.entryJumpAsset,
      ChilluSoundController.attentiveAsset,
      ChilluSoundController.listeningAsset,
      ChilluSoundController.thinkingAsset,
      ChilluSoundController.happyAsset,
      ChilluSoundController.excitedAsset,
      ChilluSoundController.celebratingAsset,
      ChilluSoundController.confusedAsset,
    ];

    expect(sounds.length, 8);

    for (final asset in sounds) {
      final file = File('assets/$asset');
      expect(file.existsSync(), isTrue, reason: 'File assets/$asset should exist on disk');
      final size = file.lengthSync();
      // At 44.1kHz 16-bit mono PCM:
      // ~1.8s = ~158,000 bytes, ~2.5s = ~220,500 bytes (+ 44-byte WAV header)
      expect(size, greaterThan(150000), reason: '$asset should be >= 1.8s');
      expect(size, lessThan(230000), reason: '$asset should be <= 2.5s');
    }
  });

  test('ChilluSoundController exposes all eight sound reaction methods', () async {
    final controller = ChilluSoundController.instance;

    // Verify all 8 reaction methods execute cleanly without throwing
    await controller.playEntryJump();
    await controller.playAttentive();
    await controller.playListening();
    await controller.playThinking();
    await controller.playHappy();
    await controller.playExcited();
    await controller.playCelebrating();
    await controller.playConfused();

    // Verify legacy alias methods also execute cleanly
    await controller.playGreetingChirp();
    await controller.playAddItemPop();
    await controller.playThinkingPing();
    await controller.playRecipeFound();
    await controller.playMealLoggedSuccess();
    await controller.playConfusedBoop();

    // Verify mute toggle
    await controller.setSoundEnabled(false);
    expect(controller.isSoundEnabled, isFalse);
    expect(controller.soundEnabledNotifier.value, isFalse);

    // Muted calls execute silently
    await controller.playHappy();

    await controller.setSoundEnabled(true);
    expect(controller.isSoundEnabled, isTrue);
    expect(controller.soundEnabledNotifier.value, isTrue);
  });

  test('ChilluSoundController diagnostics and web audio unlock mechanism work as expected', () async {
    final controller = ChilluSoundController.instance;

    // Diagnostics notifier is populated
    final initialDiag = controller.diagnosticsNotifier.value;
    expect(initialDiag.totalAssetsCount, 8);
    expect(initialDiag.isSoundEnabled, isTrue);

    // Test unlock mechanism
    await controller.unlockAudioContext();
    expect(controller.isAudioUnlocked, isTrue);
    expect(controller.diagnosticsNotifier.value.isAudioUnlocked, isTrue);

    // Test testPlay method with forced bypass
    await controller.testPlay(ChilluSoundController.entryJumpAsset);
    expect(controller.diagnosticsNotifier.value.lastPlayedAsset, ChilluSoundController.entryJumpAsset);

    // Test session reset
    controller.resetSession();
    expect(controller.hasGreetedThisSession, isFalse);
    expect(controller.isEntryJumpPending, isFalse);
  });
}
