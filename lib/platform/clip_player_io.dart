/// [ClipPlayer] of the desktop and mobile apps: audioplayers (Media Foundation, AVPlayer,
/// ExoPlayer, GStreamer). A seek pauses first, as the web one does (audioplayers_web used to
/// drop a seek made while playing).
library;

import 'package:audioplayers/audioplayers.dart';

import '../data/media_store.dart';

class ClipPlayer {
  final _player = AudioPlayer();

  /// Loads [audio]; throws when the platform cannot open it.
  Future<void> open(AudioRef audio) async => _player.setSource(switch (audio) {
    AudioFile(:final path) => DeviceFileSource(path),
    AudioUrl(:final url) => UrlSource(url),
    AudioCached(:final open) => UrlSource(await open()),
  });

  /// Moves to [seconds], paused; done once the player is there.
  Future<void> seek(double seconds) async {
    await _player.pause();
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  Future<void> play() => _player.resume();

  Future<void> pause() => _player.pause();

  /// The position while playing, in seconds.
  Stream<double> get positions => _player.onPositionChanged.map((d) => d.inMilliseconds / 1000.0);

  /// The end of the recording was reached.
  Stream<void> get completions => _player.onPlayerComplete;

  void dispose() => _player.dispose();
}
