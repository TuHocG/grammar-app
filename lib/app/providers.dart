/// Riverpod wiring: databases, services, settings, user words.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_db.dart';
import '../data/models.dart';
import '../data/search_key.dart';
import '../data/user_db.dart';
import '../data/user_db_more.dart';
import '../domain/lookup.dart';
import '../platform/tts.dart';

/// Overridden in `main` after bootstrap.
final contentDbProvider = Provider<ContentDb>((ref) => throw UnimplementedError('contentDb not bootstrapped'));
final userDbProvider = Provider<UserDb>((ref) => throw UnimplementedError('userDb not bootstrapped'));
final ttsProvider = Provider<TtsService>((ref) => throw UnimplementedError('tts not bootstrapped'));

/// Bumped whenever a progress row changes; pages that show progress ("continue" cards,
/// exercise scores, the reading being read) watch it so they refresh on return.
class ProgressRevision extends Notifier<int> {
  @override
  int build() {
    final sub = ref.watch(userDbProvider).progressChanges.listen((_) => state++);
    ref.onDispose(sub.cancel);
    return 0;
  }
}

final progressRevisionProvider = NotifierProvider<ProgressRevision, int>(ProgressRevision.new);

final lookupProvider = Provider<LookupService>((ref) => LookupService(ref.watch(contentDbProvider)));

// ---- settings ---------------------------------------------------------------

class AppSettings {
  final int ttsSpeed; // 1..7
  final String? ttsVoice;
  final double fontScale; // 0.8 .. 1.6
  final ThemeMode themeMode;
  final String? dataDir;
  const AppSettings({
    this.ttsSpeed = 4,
    this.ttsVoice,
    this.fontScale = 1.0,
    this.themeMode = ThemeMode.system,
    this.dataDir,
  });

  AppSettings copyWith({int? ttsSpeed, String? ttsVoice, bool clearVoice = false, double? fontScale, ThemeMode? themeMode, String? dataDir}) =>
      AppSettings(
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        ttsVoice: clearVoice ? null : (ttsVoice ?? this.ttsVoice),
        fontScale: fontScale ?? this.fontScale,
        themeMode: themeMode ?? this.themeMode,
        dataDir: dataDir ?? this.dataDir,
      );

  static AppSettings fromMap(Map<String, String> m) => AppSettings(
        ttsSpeed: int.tryParse(m['tts_speed'] ?? '') ?? 4,
        ttsVoice: m['tts_voice'],
        fontScale: double.tryParse(m['font_scale'] ?? '') ?? 1.0,
        themeMode: ThemeMode.values.firstWhere((t) => t.name == m['theme_mode'], orElse: () => ThemeMode.system),
        dataDir: m['data_dir'],
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.fromMap(ref.read(userDbProvider).allSettings());

  void _put(String k, String v) => ref.read(userDbProvider).setSetting(k, v);

  Future<void> setTtsSpeed(int s) async {
    _put('tts_speed', '$s');
    state = state.copyWith(ttsSpeed: s);
    await ref.read(ttsProvider).setSpeed(s);
  }

  Future<void> setTtsVoice(String? name) async {
    _put('tts_voice', name ?? '');
    state = state.copyWith(ttsVoice: name, clearVoice: name == null);
    await ref.read(ttsProvider).setVoice(name);
  }

  void setFontScale(double f) {
    _put('font_scale', '$f');
    state = state.copyWith(fontScale: f);
  }

  void setThemeMode(ThemeMode m) {
    _put('theme_mode', m.name);
    state = state.copyWith(themeMode: m);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---- user words ---------------------------------------------------------------

class UserWordsState {
  final List<UserWord> words;
  final Set<String> savedKeys;
  final Set<String> markedKeys;
  const UserWordsState(this.words, this.savedKeys, this.markedKeys);
}

class UserWordsNotifier extends Notifier<UserWordsState> {
  @override
  UserWordsState build() => _load();

  UserWordsState _load() {
    final db = ref.read(userDbProvider);
    return UserWordsState(db.words(), db.savedKeys(), db.markedKeys());
  }

  UserWord save({required String headword, String? meaning, String? ipa, String? context, String? source, bool? marked}) {
    final w = ref.read(userDbProvider).saveWord(headword: headword, meaning: meaning, ipa: ipa, context: context, source: source, marked: marked);
    state = _load();
    return w;
  }

  void remove(int id) {
    ref.read(userDbProvider).deleteWord(id);
    state = _load();
  }

  void removeByKey(String key) {
    ref.read(userDbProvider).deleteByKey(key);
    state = _load();
  }

  void removeAll() {
    ref.read(userDbProvider).deleteAllWords();
    state = _load();
  }

  void setMarked(int id, bool marked) {
    ref.read(userDbProvider).setMarked(id, marked);
    state = _load();
  }

  void setMeaning(int id, String? meaning) {
    ref.read(userDbProvider).setMeaning(id, meaning);
    state = _load();
  }
}

final userWordsProvider = NotifierProvider<UserWordsNotifier, UserWordsState>(UserWordsNotifier.new);

/// Bookmarked grammar lessons (Ngữ Pháp Của Bạn), by lesson ref.
class GrammarMarksNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.read(userDbProvider).grammarMarks();

  void toggle(int lessonRef) {
    final marked = !state.contains(lessonRef);
    ref.read(userDbProvider).setGrammarMark(lessonRef, marked);
    state = marked ? {...state, lessonRef} : ({...state}..remove(lessonRef));
  }
}

final grammarMarksProvider = NotifierProvider<GrammarMarksNotifier, Set<int>>(GrammarMarksNotifier.new);

/// Keys whose words are *underlined* in texts (docs/08 G10): every saved word and the
/// members of its Word Forms family. A text word is underlined when it, or its base form
/// (kicked → kick), is in this set and it is not itself saved (saved words are red).
final familyKeysProvider = Provider<Set<String>>((ref) {
  final saved = ref.watch(userWordsProvider).savedKeys;
  final db = ref.watch(contentDbProvider);
  final out = <String>{};
  for (final k in saved) {
    if (k.contains(' ')) continue;
    out.add(k);
    // An inflected saved word ("decided") belongs to the family of its base form.
    for (final cand in [k, ...baseFormCandidates(k)]) {
      final fam = db.familyOf(cand);
      if (fam == null) continue;
      out.add(cand);
      for (final m in fam.members) {
        // Some members carry a part of speech in the word: "outkick (v)".
        final mk = searchKey(m.word.replaceAll(RegExp(r'\s*\(.*$'), ''));
        if (mk.isNotEmpty && !mk.contains(' ')) out.add(mk);
      }
      break;
    }
  }
  return out;
});
