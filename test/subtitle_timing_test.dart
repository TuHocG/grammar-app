import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();

  test('line 1 starts where it is spoken, not at the start of the intro', () {
    final db = ContentDb.open(dir);
    final a1 = db.subtitleLines(db.films().firstWhere((f) => f.code == 'A 1').id);
    expect(a1[0].s, 34.75);
    expect(a1[0].e, 37.09);
    expect(a1[1].s, a1[0].e);
    // wordless first lines ("...") are the intro itself
    final f4 = db.subtitleLines(db.films().firstWhere((f) => f.code == 'F 4').id);
    expect(f4[0].s, 0);
  }, skip: has ? false : 'no grammar.db');
}
