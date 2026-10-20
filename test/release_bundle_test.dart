// bundle.json of a data release (tool/content/bundle.py), as the downloader reads it.
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/release_bundle.dart';

const _json = '''
{
 "content_version": "1.2.0",
 "schema_version": "1",
 "content_date": "2026-10-20",
 "files": {
  "grammar.db": {"bytes": 210075648, "sha256": "aa"},
  "grammar.db.gz": {"bytes": 87415596, "sha256": "bb"},
  "grammar.images": {"bytes": 65569942, "sha256": "cc"}
 }
}
''';

void main() {
  test('parses the files and sizes', () {
    final b = ReleaseBundle.parse(_json);
    expect(b.contentVersion, '1.2.0');
    expect(b.schema, 1);
    expect(b.date, '2026-10-20');
    expect(b.dbGz.sha256, 'bb');
    expect(b.db.bytes, 210075648);
    expect(b.images!.name, 'grammar.images');
    expect(b.downloadBytes, 87415596 + 65569942);
  });

  test('a bundle without the gzipped database is refused; malformed input is a FormatException', () {
    final b = ReleaseBundle.parse('{"content_version": "1", "schema_version": 1, "files": {"grammar.db": {"bytes": 1, "sha256": "x"}}}');
    expect(() => b.dbGz, throwsFormatException);
    expect(b.images, isNull);
    expect(() => ReleaseBundle.parse('[]'), throwsFormatException);
    expect(() => ReleaseBundle.parse('{"files": 3}'), throwsFormatException);
    expect(() => ReleaseBundle.parse('nope'), throwsFormatException);
  });
}
