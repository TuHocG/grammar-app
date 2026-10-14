import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/backup.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/data/user_db_more.dart';
import 'package:grammar/data/user_readings.dart';

void main() {
  test('a v1.0.0 backup (readings with grammar_refs) restores into the current schema', () {
    final tmp = Directory.systemTemp.createTempSync('grammar_backup');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final db = UserDb.open('${tmp.path}/user.db');
    addTearDown(db.close);
    final json = jsonEncode({
      'format': 1,
      'user_setting': [{'key': 'tts_speed', 'value': '5'}],
      'user_reading': [
        {'id': 3, 'package': 'Bài của tôi', 'title': 'Old', 'en': '[["Hi."]]', 'vi': '[["Chào."]]', 'img': null, 'grammar_refs': '[]', 'created_at': 1},
      ],
    });
    expect(importBackup(db, json), 2);
    expect(db.setting('tts_speed'), '5');
    expect(db.userReading(3)?.title, 'Old');
    expect(db.grammarMarks(), isEmpty);   // table missing from the old backup: restored empty
  });

  test('grammar marks survive export → import', () {
    final tmp = Directory.systemTemp.createTempSync('grammar_backup');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final db = UserDb.open('${tmp.path}/user.db');
    addTearDown(db.close);
    db.setGrammarMark(5, true);
    db.setGrammarMark(12, true);
    final json = exportBackup(db);
    db.setGrammarMark(5, false);
    importBackup(db, json);
    expect(db.grammarMarks(), {5, 12});
  });
}
