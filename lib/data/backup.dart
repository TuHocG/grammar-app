/// Backup and restore of everything in user.db as one JSON document (docs/08 U6, G19).
library;

import 'dart:convert';

import 'user_db.dart';

const _tables = ['user_setting', 'user_word', 'user_progress', 'user_dialog_pick', 'user_picture_pick', 'user_wordform_mark', 'user_reading', 'user_grammar_mark'];

String exportBackup(UserDb db) {
  final out = <String, Object?>{'format': 1, 'exported': DateTime.now().toIso8601String()};
  for (final t in _tables) {
    final rows = db.raw.select('SELECT * FROM $t');
    out[t] = [for (final r in rows) {for (final c in r.keys) c: r[c]}];
  }
  return const JsonEncoder.withIndent(' ').convert(out);
}

/// Replaces the user data with the backup. Returns the number of rows restored. Fields the
/// table no longer has are skipped, so backups from older versions still restore (v1.0.0
/// readings carry `grammar_refs`).
int importBackup(UserDb db, String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  if (data['format'] != 1) throw const FormatException('Không phải file sao lưu của Grammar.');
  var n = 0;
  db.raw.execute('BEGIN');
  try {
    for (final t in _tables) {
      final rows = (data[t] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final known = {for (final c in db.raw.select('PRAGMA table_info($t)')) c['name'] as String};
      db.raw.execute('DELETE FROM $t');
      for (final r in rows) {
        final cols = r.keys.where(known.contains).toList();
        db.raw.execute('INSERT INTO $t(${cols.join(',')}) VALUES (${List.filled(cols.length, '?').join(',')})', [for (final c in cols) r[c]]);
        n++;
      }
    }
    db.raw.execute('COMMIT');
    db.progressReplaced();
  } catch (e) {
    db.raw.execute('ROLLBACK');
    rethrow;
  }
  return n;
}
