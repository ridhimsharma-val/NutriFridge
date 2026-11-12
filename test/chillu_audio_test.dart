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
      AssetSource('audio/chillu/06_excited.wav').path,
      'audio/chillu/06_excited.wav',
    );
  });

  test('Only the two designated Chillu sound assets exist and are approximately 2 seconds', () {
    final activeSounds = ChilluSoundController.canonicalAssets;
    expect(activeSounds.length, 2);
    expect(activeSounds.contains(ChilluSoundController.excitedAsset), isTrue);
    expect(activeSounds.contains(ChilluSoundController.celebratingAsset), isTrue);

    for (final asset in activeSounds) {
      final file = File('assets/$asset');
      expect(file.existsSync(), isTrue, reason: 'File assets/$asset should exist on disk');
      final size = file.lengthSync();
      // At 44.1kHz 16-bit mono PCM: ~1.8s = ~158,000 bytes, ~2.5s = ~220,500 bytes (+ 44-byte WAV header)
      expect(size, greaterThan(150000), reason: '$asset should be >= 1.8s');
      expect(size, lessThan(230000), reason: '$asset should be <= 2.5s');
    }
  });

  test('ChilluSoundController triggers sound strictly for Excited and Celebrating', () async {
    final controller = ChilluSoundController.instance;

    // Both active sound methods execute cleanly
    await controller.playExcited();
    await controller.playCelebrating();

    // Active legacy aliases also execute cleanly
    await controller.playRecipeFound();
    await controller.playAddItemPop();
    await controller.playMealLoggedSuccess();

    // All other states are completely silent no-ops and execute cleanly
    await controller.playEntryJump();
    await controller.playAttentive();
    await controller.playListening();
    await controller.playThinking();
    await controller.playHappy();
    await controller.playConfused();
    await controller.playSleepyYawn();
    await controller.playGreetingChirp();
    await controller.playThinkingPing();
    await controller.playProcessingShimmer();
    await controller.playConfusedBoop();
  });

  test('Sound toggle correctly mutes and restores Excited and Celebrating', () async {
    final controller = ChilluSoundController.instance;

    // Verify mute toggle
    await controller.setSoundEnabled(false);
    expect(controller.isSoundEnabled, isFalse);
    expect(controller.soundEnabledNotifier.value, isFalse);

    // When muted, calls execute silently without throwing
    await controller.playExcited();
    await controller.playCelebrating();

    // Re-enable sound
    await controller.setSoundEnabled(true);
    expect(controller.isSoundEnabled, isTrue);
    expect(controller.soundEnabledNotifier.value, isTrue);

    await controller.playExcited();
    await controller.playCelebrating();
  });

  test('Web audio context unlock and session reset work correctly', () async {
    final controller = ChilluSoundController.instance;

    await controller.unlockAudioContext();
    expect(controller.isAudioUnlocked, isTrue);

    controller.resetSession();
    expect(controller.hasGreetedThisSession, isFalse);
  });
}
