/// [ClipPlayer] of the web app: a plain `<audio>` element, not connected to Web Audio (so no
/// CORS needed to play, and none of Safari's stale buffer after a seek). Play starts only once
/// the seek is done, and the position is read every 50 ms so a sentence stops close to its mark.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../data/media_store.dart';

class ClipPlayer {
  final _el = web.HTMLAudioElement()..preload = 'auto';
  final _positions = StreamController<double>.broadcast();
  final _completions = StreamController<void>.broadcast();
  late final StreamSubscription<web.Event> _ended;
  Timer? _ticker;

  ClipPlayer() {
    _ended = _el.onEnded.listen((_) {
      _stopTicker();
      _completions.add(null);
    });
  }

  /// Loads [audio]; throws when the browser cannot open it.
  Future<void> open(AudioRef audio) async {
    final url = switch (audio) {
      AudioUrl(:final url) => url,
      AudioCached(:final open) => await open(),
      AudioFile() => throw UnsupportedError('no files on the web'),
    };
    final loaded = _el.onLoadedMetadata.first;
    final failed = _el.onError.first;
    _el.src = url;
    _el.load();
    await Future.any([loaded, failed.then<web.Event>((_) => throw StateError('cannot load $url (${_el.error?.code})'))]);
  }

  /// Moves to [seconds], paused; done once the browser is there (`seeked`).
  Future<void> seek(double seconds) async {
    _el.pause();
    _stopTicker();
    if (!_el.seeking && (_el.currentTime - seconds).abs() < 0.01) return;
    final seeked = _el.onSeeked.first;
    _el.currentTime = seconds;
    await seeked.timeout(const Duration(seconds: 15));
  }

  Future<void> play() async {
    await _el.play().toDart;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _positions.add(_el.currentTime.toDouble()));
  }

  Future<void> pause() async {
    _el.pause();
    _stopTicker();
  }

  /// The position while playing, in seconds.
  Stream<double> get positions => _positions.stream;

  /// The end of the recording was reached.
  Stream<void> get completions => _completions.stream;

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void dispose() {
    _stopTicker();
    _ended.cancel();
    _el.pause();
    _el.removeAttribute('src');
    _el.load(); // lets the browser drop the stream
    _positions.close();
    _completions.close();
  }
}
