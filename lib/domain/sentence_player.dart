/// SentencePlayer: reads a list of sentences one by one, either with TTS or with the real
/// recording and its per-sentence time marks (docs/08 R5, R6). Exposes the current index so
/// the UI can highlight the sentence; arrows move around; repeat replays the current one.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/media_store.dart';
import '../data/models.dart';
import '../platform/clip_player.dart';
import '../platform/tts.dart';

enum PlayerState { idle, playing, paused }

class SentencePlayer extends ChangeNotifier {
  final TtsService tts;
  final Reading reading;

  /// The recording (null → TTS).
  final AudioRef? audio;

  int index = 0;
  PlayerState state = PlayerState.idle;

  /// Keep reading the next sentence after the current one ends.
  bool continuous = true;

  ClipPlayer? _player;
  StreamSubscription<double>? _posSub;
  StreamSubscription<void>? _doneSub;
  int _run = 0;
  double? _stopAt;

  /// Set when the platform cannot play the recording (e.g. a codec it lacks); the player
  /// then reads with TTS for the rest of its life instead of stalling on every sentence.
  bool _recordingFailed = false;
  bool _sourceSet = false;
  Completer<void>? _segment;

  /// False when the page is replaced by one that may already be speaking through the
  /// shared [tts]; that page stops the old one itself before navigating.
  bool stopTtsOnDispose = true;

  /// Makes the clip player of the recording; tests pass a fake.
  final ClipPlayer Function() newClip;

  SentencePlayer({required this.tts, required this.reading, this.audio, @visibleForTesting this.newClip = ClipPlayer.new}) {
    _live.add(this);
  }

  /// The players of the pages still on the navigation stack.
  static final _live = <SentencePlayer>{};

  /// Stops every player, when a page opens over the one reading aloud: go_router keeps the
  /// page below alive, so it would go on reading (`StopReadingObserver`, app/router.dart).
  static void stopAll() {
    for (final p in [..._live]) {
      if (p.state == PlayerState.playing) p.stop();
    }
  }

  bool get useRecording => audio != null && reading.hasRealAudio && !_recordingFailed;

  /// The recording could not be played (a stream while offline, a codec the platform lacks):
  /// the sentences are read with TTS instead.
  bool get recordingFailed => _recordingFailed;
  int get count => reading.sentences.length;
  Sentence get current => reading.sentences[index];

  /// [continuous] overrides the field for this run only (speakOnce passes false), so a
  /// second tap while a sentence is being read cannot flip a shared flag and let the
  /// newer run keep going through the whole reading.
  Future<void> play({int? from, bool? continuous}) async {
    if (from != null) index = from.clamp(0, count - 1);
    final run = ++_run;
    state = PlayerState.playing;
    notifyListeners();
    while (run == _run && state == PlayerState.playing) {
      await _speakCurrent(run);
      if (run != _run || state != PlayerState.playing) break;
      if (!(continuous ?? this.continuous) || index >= count - 1) {
        state = PlayerState.idle;
        notifyListeners();
        break;
      }
      index++;
      notifyListeners();
    }
  }

  Future<void> _speakCurrent(int run) async {
    if (useRecording) {
      try {
        await _playSegment(reading.times![index], reading.times![index + 1], run);
        return;
      } on _Refused {
        _halt(run);
        return;
      } catch (e) {
        // A run superseded while its stream was loading (a tap on another sentence) may fail
        // because of the newer one: that says nothing about the recording.
        if (run != _run) return;
        debugPrint('SentencePlayer: cannot play $audio, falling back to TTS: $e');
        _recordingFailed = true;
        notifyListeners();
      }
    }
    await tts.speak(current.en);
  }

  Future<void> _playSegment(double start, double end, int run) async {
    final p = _player ??= newClip();
    _endSegment();
    final done = _segment = Completer<void>();
    _stopAt = end;
    await _posSub?.cancel();
    await _doneSub?.cancel();
    // Load the file once; play(source, position:) would reload it and report the position
    // left by the previous sentence before seeking, which ended a replay (or a jump back)
    // as soon as it started.
    if (!_sourceSet) {
      // A stream that never answers (captive portal, dead host) must not hold the reading up.
      await p.open(audio!).timeout(const Duration(seconds: 20));
      _sourceSet = true;
    }
    // Paused first, then played from where the seek landed: never a moment of the old position.
    await p.seek(start);
    if (run != _run) return;
    // Listen only once the seek is done, so every position seen belongs to this sentence.
    _posSub = p.positions.listen((t) {
      if (_stopAt != null && t >= _stopAt! - 0.05 && !done.isCompleted) {
        done.complete();
      }
    });
    _doneSub = p.completions.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await p.play();
    } catch (e) {
      // The file is open and in place, so this is the browser refusing to start (autoplay
      // without a fresh tap) or a pause racing the start: not a reason to give up the recording.
      if (run != _run) return;
      debugPrint('SentencePlayer: play refused: $e');
      throw const _Refused();
    }
    await done.future;
    if (run == _run) await p.pause();
  }

  /// After a refused start: the run ends, silent; the next tap (a real gesture) tries again.
  void _halt(int run) {
    if (run != _run) return;
    _run++;
    state = PlayerState.idle;
    notifyListeners();
  }

  /// Lets a segment that was superseded or stopped return instead of waiting forever.
  void _endSegment() {
    final s = _segment;
    if (s != null && !s.isCompleted) s.complete();
  }

  /// Play the title part of the recording (before sentence 0), when the file has it.
  Future<void> playTitle() async {
    if (!useRecording || !reading.titleAudio) return;
    final run = ++_run;
    state = PlayerState.playing;
    notifyListeners();
    try {
      await _playSegment(0, reading.times![0], run);
    } on _Refused {
      _halt(run);
    } catch (e) {
      debugPrint('SentencePlayer: cannot play $audio: $e');
      if (run == _run) _recordingFailed = true;
    }
    if (run == _run) {
      state = PlayerState.idle;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final run = ++_run;
    state = PlayerState.idle;
    _endSegment();
    await tts.stop();
    // A run started meanwhile (a quick tap after the stop) paused and moved the clip itself:
    // pausing now would cut it off mid-sentence.
    if (run == _run) await _player?.pause();
    notifyListeners();
  }

  Future<void> repeat() => play(from: index);

  Future<void> next() async {
    if (index < count - 1) await play(from: index + 1);
  }

  Future<void> previous() async {
    if (index > 0) await play(from: index - 1);
  }

  /// Speak one sentence only (reading page, dictation).
  Future<void> speakOnce(int i) => play(from: i, continuous: false);

  /// True while sentence [i] is being read.
  bool isSpeaking(int i) => state == PlayerState.playing && index == i;

  @override
  void dispose() {
    _live.remove(this);
    _run++;
    _endSegment();
    _posSub?.cancel();
    _doneSub?.cancel();
    _player?.dispose();
    if (stopTtsOnDispose) tts.stop();
    super.dispose();
  }
}

/// The recording could not start playing although it is loaded (see [SentencePlayer._halt]).
class _Refused implements Exception {
  const _Refused();
}
