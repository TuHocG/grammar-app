/// `user.db`: everything the user creates or changes (docs/09 §3). Replaces the old
/// app's data.Kcu, dataChon.txt, DataTuDienUser.txt, DataSpChon, user flags in data files.
library;

import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import 'models.dart';
import 'search_key.dart';

class UserDb {
  final Database _db;
  UserDb._(this._db);

  static UserDb open(String file) {
    final db = sqlite3.open(file);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS user_setting (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS user_word (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        headword TEXT NOT NULL,
        key TEXT NOT NULL,
        meaning TEXT,
        ipa TEXT,
        context TEXT,
        source TEXT,
        added_at INTEGER NOT NULL,
        marked INTEGER NOT NULL DEFAULT 0
      );
      CREATE UNIQUE INDEX IF NOT EXISTS user_word_key ON user_word(key);
      CREATE TABLE IF NOT EXISTS user_progress (
        kind TEXT NOT NULL, item_id TEXT NOT NULL, state TEXT NOT NULL, updated_at INTEGER NOT NULL,
        PRIMARY KEY (kind, item_id)
      );
      CREATE TABLE IF NOT EXISTS user_dialog_pick (dialog_id INTEGER NOT NULL, pair_idx INTEGER NOT NULL, ord INTEGER NOT NULL, PRIMARY KEY (dialog_id, pair_idx));
      CREATE TABLE IF NOT EXISTS user_picture_pick (topic_id INTEGER NOT NULL, word_idx INTEGER NOT NULL, PRIMARY KEY (topic_id, word_idx));
      CREATE TABLE IF NOT EXISTS user_wordform_mark (root_position INTEGER PRIMARY KEY, level INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS user_reading (
        id INTEGER PRIMARY KEY AUTOINCREMENT, package TEXT NOT NULL, title TEXT NOT NULL,
        en TEXT NOT NULL, vi TEXT NOT NULL, img TEXT, created_at INTEGER NOT NULL
      );
    ''');
    return UserDb._(db);
  }

  final _progressChanges = StreamController<void>.broadcast();

  /// Fires after a progress row changes value. Delivered asynchronously, so pages that
  /// save progress in `initState`/`build` never notify listeners mid-build.
  Stream<void> get progressChanges => _progressChanges.stream;

  void close() {
    _progressChanges.close();
    _db.close();
  }

  /// Raw handle for extensions in other files.
  Database get raw => _db;

  // ---- settings -----------------------------------------------------------

  String? setting(String key) {
    final rows = _db.select('SELECT value FROM user_setting WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String value) =>
      _db.execute('INSERT INTO user_setting(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', [key, value]);

  Map<String, String> allSettings() => {
        for (final r in _db.select('SELECT key, value FROM user_setting')) r['key'] as String: r['value'] as String,
      };

  // ---- progress -----------------------------------------------------------

  String? progress(String kind, String itemId) {
    final rows = _db.select('SELECT state FROM user_progress WHERE kind = ? AND item_id = ?', [kind, itemId]);
    return rows.isEmpty ? null : rows.first['state'] as String;
  }

  /// When a progress row was last written (ms since epoch), or null.
  int? progressTime(String kind, String itemId) {
    final rows = _db.select('SELECT updated_at FROM user_progress WHERE kind = ? AND item_id = ?', [kind, itemId]);
    return rows.isEmpty ? null : rows.first['updated_at'] as int;
  }

  /// All progress rows of one kind, keyed by item id (e.g. every exercise group done).
  Map<String, String> progressOf(String kind, {String prefix = ''}) => {
        for (final r in _db.select('SELECT item_id, state FROM user_progress WHERE kind = ? AND item_id LIKE ?', [kind, '$prefix%']))
          r['item_id'] as String: r['state'] as String,
      };

  /// Most recently updated row of one kind (what the learner was doing last), or null.
  (String itemId, String state)? latestProgress(String kind, {String prefix = ''}) {
    final rows = _db.select('SELECT item_id, state FROM user_progress WHERE kind = ? AND item_id LIKE ? ORDER BY updated_at DESC LIMIT 1', [kind, '$prefix%']);
    return rows.isEmpty ? null : (rows.first['item_id'] as String, rows.first['state'] as String);
  }

  int? _lastStamp;

  /// Strictly increasing write time, so the newest row is unambiguous even when a page
  /// saves several rows within one millisecond.
  int _progressStamp() {
    final last = _lastStamp ??= _db.select('SELECT MAX(updated_at) AS t FROM user_progress').first['t'] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return _lastStamp = now > last ? now : last + 1;
  }

  /// Call after progress rows are rewritten wholesale (restoring a backup).
  void progressReplaced() {
    _lastStamp = null;
    _progressChanges.add(null);
  }

  void setProgress(String kind, String itemId, String state) {
    final newest = _db.select('SELECT kind, item_id FROM user_progress ORDER BY updated_at DESC LIMIT 1');
    final wasNewest = newest.isNotEmpty && newest.first['kind'] == kind && newest.first['item_id'] == itemId;
    // Reopening an older item keeps its value but makes it the most recent ("Đang học").
    final changed = !wasNewest || progress(kind, itemId) != state;
    _db.execute(
      'INSERT INTO user_progress(kind, item_id, state, updated_at) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(kind, item_id) DO UPDATE SET state = excluded.state, updated_at = excluded.updated_at',
      [kind, itemId, state, _progressStamp()],
    );
    // Rewriting the newest row with the same value still bumps updated_at but does not
    // notify, so a page that saves in `build` and also watches progress does not rebuild
    // itself forever.
    if (changed) _progressChanges.add(null);
  }

  // ---- user words -----------------------------------------------------------

  List<UserWord> words({bool markedOnly = false}) => [
        for (final r in _db.select(
          'SELECT * FROM user_word ${markedOnly ? 'WHERE marked = 1' : ''} ORDER BY added_at, id',
        ))
          _word(r),
      ];

  Set<String> savedKeys() => {
        for (final r in _db.select('SELECT key FROM user_word')) r['key'] as String,
      };

  Set<String> markedKeys() => {
        for (final r in _db.select('SELECT key FROM user_word WHERE marked = 1')) r['key'] as String,
      };

  UserWord? wordByKey(String key) {
    final rows = _db.select('SELECT * FROM user_word WHERE key = ?', [key]);
    return rows.isEmpty ? null : _word(rows.first);
  }

  /// Insert or update; returns the stored row.
  UserWord saveWord({
    required String headword,
    String? meaning,
    String? ipa,
    String? context,
    String? source,
    bool? marked,
  }) {
    final key = searchKey(headword);
    final existing = wordByKey(key);
    if (existing == null) {
      _db.execute(
        'INSERT INTO user_word(headword, key, meaning, ipa, context, source, added_at, marked) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [headword, key, meaning, ipa, context, source, DateTime.now().millisecondsSinceEpoch, (marked ?? false) ? 1 : 0],
      );
    } else {
      _db.execute(
        'UPDATE user_word SET headword = ?, meaning = COALESCE(?, meaning), ipa = COALESCE(?, ipa), '
        'context = COALESCE(?, context), source = COALESCE(?, source), marked = ? WHERE key = ?',
        [headword, meaning, ipa, context, source, (marked ?? existing.marked) ? 1 : 0, key],
      );
    }
    return wordByKey(key)!;
  }

  void setMeaning(int id, String? meaning) => _db.execute('UPDATE user_word SET meaning = ? WHERE id = ?', [meaning, id]);

  void setMarked(int id, bool marked) => _db.execute('UPDATE user_word SET marked = ? WHERE id = ?', [marked ? 1 : 0, id]);

  void deleteWord(int id) => _db.execute('DELETE FROM user_word WHERE id = ?', [id]);

  void deleteByKey(String key) => _db.execute('DELETE FROM user_word WHERE key = ?', [key]);

  void deleteAllWords() => _db.execute('DELETE FROM user_word');

  // ---- Word Forms marks (old app: Chon byte 4 = bright red, 3 = dark red) -------------

  Map<int, int> wordformMarks() => {
        for (final r in _db.select('SELECT root_position, level FROM user_wordform_mark')) r['root_position'] as int: r['level'] as int,
      };

  void setWordformMark(int position, int level) {
    if (level == 0) {
      _db.execute('DELETE FROM user_wordform_mark WHERE root_position = ?', [position]);
    } else {
      _db.execute('INSERT INTO user_wordform_mark(root_position, level) VALUES (?, ?) ON CONFLICT(root_position) DO UPDATE SET level = excluded.level', [position, level]);
    }
  }

  void clearWordformMarks() => _db.execute('DELETE FROM user_wordform_mark');

  UserWord _word(Row r) => UserWord(
        id: r['id'] as int,
        headword: r['headword'] as String,
        key: r['key'] as String,
        meaning: r['meaning'] as String?,
        ipa: r['ipa'] as String?,
        context: r['context'] as String?,
        source: r['source'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(r['added_at'] as int),
        marked: (r['marked'] as int) == 1,
      );
}
