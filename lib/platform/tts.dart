/// Text-to-speech through the platform engine (replaces SAPI SpVoice, docs/08 G15).
/// Speed 1–7 maps to the old app's SAPI rates −10/−6/−3/0/2/4/8 (PopUpWav.bas:TocDoDoc2),
/// re-scaled onto flutter_tts's 0..1 range.
library;

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class TtsVoice {
  final String name;
  final String locale;
  const TtsVoice(this.name, this.locale);
  @override
  String toString() => '$name ($locale)';
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  int _speed = 4;
  String? _voiceName;

  /// SAPI rate −10..8 → speech rate factor; 0 (speed 4) is the engine's normal speed.
  static const _sapiRate = [-10, -6, -3, 0, 2, 4, 8];

  static double rateFor(int speed) {
    final r = _sapiRate[(speed - 1).clamp(0, 6)];
    // SAPI: each rate unit ≈ 10 % of normal speed; keep within what engines accept.
    final factor = 1.0 + r * 0.10;
    return (0.5 * factor).clamp(0.2, 1.0);
  }

  Future<void> init({int speed = 4, String? voiceName}) async {
    _speed = speed;
    _voiceName = voiceName;
    await _tts.setLanguage('en-US');
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(rateFor(speed));
    if (voiceName != null) await _applyVoice(voiceName);
    _ready = true;
  }

  Future<List<TtsVoice>> voices() async {
    final raw = await _tts.getVoices;
    final out = <TtsVoice>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString();
          if (locale.toLowerCase().startsWith('en')) {
            out.add(TtsVoice((v['name'] ?? '').toString(), locale));
          }
        }
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<void> _applyVoice(String name) async {
    final all = await voices();
    final v = all.where((x) => x.name == name).firstOrNull;
    if (v != null) await _tts.setVoice({'name': v.name, 'locale': v.locale});
  }

  Future<void> setSpeed(int speed) async {
    _speed = speed;
    await _tts.setSpeechRate(rateFor(speed));
  }

  Future<void> setVoice(String? name) async {
    _voiceName = name;
    if (name != null) await _applyVoice(name);
  }

  int get speed => _speed;
  String? get voiceName => _voiceName;

  Future<void> speak(String text) async {
    if (!_ready) await init(speed: _speed, voiceName: _voiceName);
    await _tts.stop();
    if (text.trim().isEmpty) return;
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
