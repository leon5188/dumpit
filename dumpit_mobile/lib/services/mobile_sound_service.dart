import 'package:audioplayers/audioplayers.dart';

class MobileSoundService {
  static final MobileSoundService _instance = MobileSoundService._();
  factory MobileSoundService() => _instance;
  MobileSoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _chimeLoaded = false;
  bool _suckLoaded = false;

  Future<void> _ensureLoaded(String asset) async {
    try {
      await _player.setSource(AssetSource(asset));
    } on Exception {
      // ignore preload failures; play will attempt again
    }
  }

  Future<void> playChime() async {
    if (!_chimeLoaded) {
      await _ensureLoaded('sounds/chime.wav');
      _chimeLoaded = true;
    }
    await _player.play(AssetSource('sounds/chime.wav'));
  }

  Future<void> playSuck() async {
    if (!_suckLoaded) {
      await _ensureLoaded('sounds/suck.wav');
      _suckLoaded = true;
    }
    await _player.play(AssetSource('sounds/suck.wav'));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
