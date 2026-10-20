// SentencePlayer with a fake TTS: a second tap on a sentence while it is being read
// must not turn into continuous reading, and stop() must stop.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/media_store.dart';
import 'package:grammar/data/models.dart';
import 'package:grammar/domain/sentence_player.dart';
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
}
