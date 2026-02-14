import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playSiren() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/sirene.mp3'));
    } catch (e) {
      print('Error playing siren: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await _player.stop();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
