import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';

void main() {
  test('open fails at once on a file that is not a database (e.g. the encrypted grammar.db of 1.0.x)', () {
    final dir = Directory.systemTemp.createTempSync('grammar_open_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final rnd = Random(1);
    File('${dir.path}/grammar.db').writeAsBytesSync([for (var i = 0; i < 8192; i++) rnd.nextInt(256)]);
    expect(() => ContentDb.open(dir.path), throwsA(anything));
  });
}
