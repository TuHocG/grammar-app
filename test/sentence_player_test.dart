// SentencePlayer with a fake TTS: a second tap on a sentence while it is being read
// must not turn into continuous reading, and stop() must stop.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/router.dart';
import 'package:grammar/data/media_store.dart';
import 'package:grammar/data/models.dart';
import 'package:grammar/domain/sentence_player.dart';
import 'package:grammar/platform/clip_player.dart';
import 'package:grammar/platform/tts.dart';

class FakeTts extends TtsService {
  final spoken = <String>[];
  Completer<void>? _cur;
  @override
  Future<void> speak(String text) async {
    _cur?.complete();
    spoken.add(text);
    final c = _cur = Completer<void>();
    await c.future;
  }

  @override
  Future<void> stop() async {
    _cur?.complete();
    _cur = null;
  }

  /// Let the current utterance finish on its own.
  void finish() {
    _cur?.complete();
    _cur = null;
  }
}

Reading reading(int n) => Reading(id: 1, sid: 1, position: 1, title: 'T', titleAudio: false, sentences: [for (var i = 0; i < n; i++) Sentence(i, 0, 'S$i', 'V$i')]);

void main() {
  // TtsService builds the real backend (FlutterTts: under flutter test the platform reads as Android), which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speakOnce reads one sentence and stops', () async {
    final tts = FakeTts();
    final p = SentencePlayer(tts: tts, reading: reading(5));
    final f = p.speakOnce(1);
    await Future<void>.delayed(Duration.zero);
    expect(p.isSpeaking(1), isTrue);
    tts.finish();
    await f;
    expect(tts.spoken, ['S1']);
    expect(p.state, PlayerState.idle);
  });

  test('a second speakOnce while speaking does not become continuous reading', () async {
    final tts = FakeTts();
    final p = SentencePlayer(tts: tts, reading: reading(5));
    final f1 = p.speakOnce(1);
    await Future<void>.delayed(Duration.zero);
    final f2 = p.speakOnce(1); // second tap: restarts the same sentence
    await Future<void>.delayed(Duration.zero);
    tts.finish();
    await f1;
    await f2;
    await Future<void>.delayed(Duration.zero);
    expect(tts.spoken, ['S1', 'S1']); // never S2, S3, ...
    expect(p.state, PlayerState.idle);
  });

  test('stop() during speakOnce ends it', () async {
    final tts = FakeTts();
    final p = SentencePlayer(tts: tts, reading: reading(5));
    final f = p.speakOnce(0);
    await Future<void>.delayed(Duration.zero);
    await p.stop();
    await f;
    expect(p.state, PlayerState.idle);
    expect(tts.spoken, ['S0']);
  });

  test('play() keeps going; the listen page toggle still applies live', () async {
    final tts = FakeTts();
    final p = SentencePlayer(tts: tts, reading: reading(3));
    final f = p.play();
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
      tts.finish();
    }
    await f;
    expect(tts.spoken, ['S0', 'S1', 'S2']);
    expect(p.state, PlayerState.idle);
  });

  test('a recording the platform cannot play falls back to TTS', () async {
    // No audio plugin in tests, so playing the file fails like an unsupported codec does.
    final tts = FakeTts();
    final r = Reading(id: 1, sid: 1, position: 1, title: 'T', titleAudio: false, audio: 'audio/2.mp3', times: [0, 1, 2], sentences: [Sentence(0, 0, 'S0', 'V0'), Sentence(1, 0, 'S1', 'V1')]);
    final p = SentencePlayer(tts: tts, reading: r, audio: const AudioFile('missing.mp3'));
    expect(p.useRecording, isTrue);
    final f = p.speakOnce(0);
    await pumpEventQueue();
    expect(tts.spoken, ['S0']);
    expect(p.useRecording, isFalse);
    tts.finish();
    await f;
    expect(p.state, PlayerState.idle);
  });

  testWidgets('opening a page over the one reading aloud stops it; a sheet does not', (tester) async {
    final tts = FakeTts();
    final p = SentencePlayer(tts: tts, reading: reading(5));
    addTearDown(p.dispose);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, navigatorObservers: [StopReadingObserver()], home: const SizedBox()));
    unawaited(p.play(from: 0));
    await tester.pump();
    unawaited(showModalBottomSheet<void>(context: nav.currentContext!, builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();
    expect(p.state, PlayerState.playing);
    unawaited(nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SizedBox())));
    await tester.pumpAndSettle();
    expect(p.state, PlayerState.idle);
    expect(tts.spoken, ['S0']);
  });

  group('with a recording', () {
    Reading recorded() =>
        Reading(id: 1, sid: 1, position: 1, title: 'T', titleAudio: false, audio: 'audio/1.mp3', times: [0, 1, 2, 3], sentences: [for (var i = 0; i < 3; i++) Sentence(i, 0, 'S$i', 'V$i')]);

    test('a refused start ends the run without giving up the recording', () async {
      final tts = FakeTts();
      final clip = FakeClip()..refuse = true;
      final p = SentencePlayer(tts: tts, reading: recorded(), audio: const AudioUrl('u'), newClip: () => clip);
      addTearDown(p.dispose);
      await p.speakOnce(1);
      expect(p.state, PlayerState.idle);
      expect(p.recordingFailed, isFalse);
      expect(tts.spoken, isEmpty); // no machine voice over a recording that may play on the next tap
      clip.refuse = false;
      final f = p.speakOnce(1);
      await pumpEventQueue();
      expect(clip.events.last, 'play 1.0');
      clip.reach(2);
      await f;
      expect(p.state, PlayerState.idle);
    });

    test('a stop still waiting for TTS does not pause the run that started after it', () async {
      final tts = SlowStopTts();
      final clip = FakeClip();
      final p = SentencePlayer(tts: tts, reading: recorded(), audio: const AudioUrl('u'), newClip: () => clip);
      addTearDown(p.dispose);
      unawaited(p.speakOnce(0));
      await pumpEventQueue();
      final stopping = p.stop(); // waits for tts.stop()
      unawaited(p.speakOnce(2));
      await pumpEventQueue();
      expect(clip.events.last, 'play 2.0');
      tts.release();
      await stopping;
      expect(clip.events.last, 'play 2.0');
      expect(p.state, PlayerState.playing);
    });
  });
}

/// A clip player that plays only when told where it got to ([reach]).
class FakeClip implements ClipPlayer {
  final events = <String>[];
  final _positions = StreamController<double>.broadcast();
  final _completions = StreamController<void>.broadcast();
  bool refuse = false;
  double _at = 0;

  void reach(double t) => _positions.add(t);

  @override
  Future<void> open(AudioRef audio) async => events.add('open');
  @override
  Future<void> seek(double seconds) async {
    events.add('pause');
    _at = seconds;
  }

  @override
  Future<void> play() async {
    if (refuse) throw StateError('NotAllowedError');
    events.add('play $_at');
  }

  @override
  Future<void> pause() async => events.add('pause');
  @override
  Stream<double> get positions => _positions.stream;
  @override
  Stream<void> get completions => _completions.stream;
  @override
  void dispose() {}
}

/// A TTS whose stop() takes its time, like the platform engines.
class SlowStopTts extends FakeTts {
  final _released = Completer<void>();
  void release() => _released.complete();
  @override
  Future<void> stop() async {
    await super.stop();
    await _released.future;
  }
}
