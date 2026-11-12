import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AudioPlayer creates without error and uses assets/ prefix', () {
    final player = AudioPlayer();
    expect(player.audioCache.prefix, 'assets/');
    expect(
      AssetSource('audio/chillu/01_greeting_chirp.wav').path,
      'audio/chillu/01_greeting_chirp.wav',
    );
  });
}
