/// Text-to-speech (docs/08 G15). Speed 1–7 maps to the old app's SAPI rates
/// −10/−6/−3/0/2/4/8 (PopUpWav.bas:TocDoDoc2).
///
/// Windows: our own SAPI channel in the runner (`windows/runner/sapi_tts.cpp`), the very
/// engine Grammar 3.1 used; `flutter_tts` crashes there (access violation in its WinRT
/// MediaPlayer path on this machine). Other platforms: `flutter_tts`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsVoice {
  /// Stable identifier passed back to `setVoice` (SAPI token id, or flutter_tts name).
  final String id;
  final String name;
  final String locale;
  const TtsVoice(this.id, this.name, [this.locale = '']);
  @override
  String toString() => locale.isEmpty ? name : '$name ($locale)';
}

abstract class TtsBackend {
  Future<void> init();
  Future<List<TtsVoice>> voices();
  Future<void> setVoice(String? id);
  Future<void> setRate(int sapiRate);

  /// Speaks and completes when the utterance has finished (or was stopped).
  Future<void> speak(String text);

  /// Speaks after whatever is playing now, without cutting it off.
  Future<void> speakAfter(String text);
  Future<void> stop();
}

class TtsService {
  static const sapiRate = [-10, -6, -3, 0, 2, 4, 8];

  final TtsBackend _b = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? _SapiBackend() : _FlutterTtsBackend();
  bool _ready = false;
  int _speed = 4;
  String? _voiceId;

  int get speed => _speed;
  String? get voiceName => _voiceId;

  static int rateFor(int speed) => sapiRate[(speed - 1).clamp(0, 6)];

  Future<void> init({int speed = 4, String? voiceName}) async {
    _speed = speed;
    _voiceId = voiceName;
    try {
      await _b.init();
      await _b.setRate(rateFor(speed));
      if (voiceName != null && voiceName.isNotEmpty) await _b.setVoice(voiceName);
    } catch (_) {
      // TTS is optional; the app must still work without a voice.
    }
    _ready = true;
  }

  Future<List<TtsVoice>> voices() async {
    try {
      return await _b.voices();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSpeed(int speed) async {
    _speed = speed;
    await _b.setRate(rateFor(speed));
  }

  Future<void> setVoice(String? id) async {
    _voiceId = id;
    await _b.setVoice(id);
  }

  Future<void> speak(String text) async {
    if (!_ready) await init(speed: _speed, voiceName: _voiceId);
    if (text.trim().isEmpty) return;
    try {
      await _b.speak(text);
    } catch (_) {}
  }

  /// Like [speak], but never cuts off the utterance still playing (Android queues it).
  Future<void> speakAfter(String text) async {
    if (!_ready) await init(speed: _speed, voiceName: _voiceId);
    if (text.trim().isEmpty) return;
    try {
      await _b.speakAfter(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _b.stop();
    } catch (_) {}
  }
}

// ---- Windows: SAPI via method channel ------------------------------------------------

class _SapiBackend implements TtsBackend {
  static const _ch = MethodChannel('grammar/tts');
  int _gen = 0;

  @override
  Future<void> init() async {}

  @override
  Future<List<TtsVoice>> voices() async {
    final raw = await _ch.invokeMethod<List<Object?>>('getVoices') ?? const [];
    return [for (final v in raw.cast<Map<Object?, Object?>>()) TtsVoice((v['id'] ?? '').toString(), (v['name'] ?? '').toString())];
  }

  @override
  Future<void> setVoice(String? id) => _ch.invokeMethod('setVoice', {'id': id ?? ''});

  @override
  Future<void> setRate(int sapiRate) => _ch.invokeMethod('setRate', {'rate': sapiRate});

  @override
  Future<void> speak(String text) async {
    final gen = ++_gen;
    final ok = await _ch.invokeMethod<bool>('speak', {'text': text}) ?? false;
    if (!ok) return;
    // SAPI is asynchronous; poll until it is no longer speaking. Completion callbacks from
    // SAPI's own thread are what crashes flutter_tts, so we never use them.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    while (gen == _gen) {
      final speaking = await _ch.invokeMethod<bool>('isSpeaking') ?? false;
      if (!speaking) break;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  /// [speak] polls SAPI until it really is silent, so nothing is still playing here.
  @override
  Future<void> speakAfter(String text) => speak(text);

  @override
  Future<void> stop() async {
    _gen++;
    await _ch.invokeMethod('stop');
  }
}

// ---- Android, iOS, macOS, Linux: flutter_tts --------------------------------------

class _FlutterTtsBackend implements TtsBackend {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<List<TtsVoice>> voices() async {
    final raw = await _tts.getVoices;
    final out = <TtsVoice>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString();
          if (locale.toLowerCase().startsWith('en')) {
            final name = (v['name'] ?? '').toString();
            out.add(TtsVoice(name, name, locale));
          }
        }
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<void> setVoice(String? id) async {
    if (id == null || id.isEmpty) return;
    final v = (await voices()).where((x) => x.id == id).firstOrNull;
    if (v != null) await _tts.setVoice({'name': v.name, 'locale': v.locale});
  }

  @override
  Future<void> setRate(int sapiRate) async {
    // Each SAPI unit ≈ 10 % of normal speed; flutter_tts normal speed is 0.5.
    final factor = 1.0 + sapiRate * 0.10;
    await _tts.setSpeechRate((0.5 * factor).clamp(0.2, 1.0));
  }

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Android's completion can fire before the utterance has really finished (a late
  /// callback from the stopped one), so stop + speak would swallow it: queue instead.
  /// Queued speech does not await completion.
  @override
  Future<void> speakAfter(String text) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return speak(text);
    await _tts.setQueueMode(1);
    try {
      await _tts.speak(text);
    } finally {
      await _tts.setQueueMode(0);
    }
  }

  @override
  Future<void> stop() => _tts.stop();
}
