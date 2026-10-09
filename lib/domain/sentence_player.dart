/// SentencePlayer: reads a list of sentences one by one, either with TTS or with the real
/// recording and its per-sentence time marks (docs/08 R5, R6). Exposes the current index so
/// the UI can highlight the sentence; arrows move around; repeat replays the current one.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../platform/tts.dart';

enum PlayerState { idle, playing, paused }

class SentencePlayer extends ChangeNotifier {
  final TtsService tts;
  final Reading reading;
  /// Absolute path of the recording (null → TTS).
  final String? audioPath;

  int index = 0;
  PlayerState state = PlayerState.idle;
  /// Keep reading the next sentence after the current one ends.
  bool continuous = true;

  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;
  int _run = 0;
  double? _stopAt;
  /// Set when the platform cannot play the recording (e.g. a codec it lacks); the player
  /// then reads with TTS for the rest of its life instead of stalling on every sentence.
  bool _recordingFailed = false;

  SentencePlayer({required this.tts, required this.reading, this.audioPath});

  bool get useRecording => audioPath != null && reading.hasRealAudio && !_recordingFailed;
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
      } catch (e) {
        debugPrint('SentencePlayer: cannot play $audioPath, falling back to TTS: $e');
        _recordingFailed = true;
        notifyListeners();
      }
    }
    await tts.speak(current.en);
  }

  Future<void> _playSegment(double start, double end, int run) async {
    final p = _player ??= AudioPlayer();
    final done = Completer<void>();
    _stopAt = end;
    await _posSub?.cancel();
    await _doneSub?.cancel();
    _posSub = p.onPositionChanged.listen((d) {
      if (_stopAt != null && d.inMilliseconds / 1000.0 >= _stopAt! - 0.05 && !done.isCompleted) {
        done.complete();
      }
    });
    _doneSub = p.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    await p.play(DeviceFileSource(audioPath!), position: Duration(milliseconds: (start * 1000).round()));
    await done.future;
    if (run == _run) await p.pause();
  }

  /// Play the title part of the recording (before sentence 0), when the file has it.
  Future<void> playTitle() async {
    if (!useRecording || !reading.titleAudio) return;
    final run = ++_run;
    state = PlayerState.playing;
    notifyListeners();
    try {
      await _playSegment(0, reading.times![0], run);
    } catch (e) {
      debugPrint('SentencePlayer: cannot play $audioPath: $e');
      _recordingFailed = true;
    }
    if (run == _run) {
      state = PlayerState.idle;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _run++;
    state = PlayerState.idle;
    await tts.stop();
    await _player?.pause();
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
    _run++;
    _posSub?.cancel();
    _doneSub?.cancel();
    _player?.dispose();
    tts.stop();
    super.dispose();
  }
}
