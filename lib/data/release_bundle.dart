/// `bundle.json` of a data release (tool/content/bundle.py): the content version and the size and
/// sha256 of each file next to it. The desktop and mobile apps download it from GitHub Releases
/// (docs/07 §12) to fetch `grammar.db.gz` and `grammar.images`.
library;

import 'dart:convert';

/// Orders content versions `x.y.z` numerically (`1.10.0` after `1.9.0`); an unparsable part
/// sorts as 0. Positive when [a] is newer than [b].
int compareVersions(String a, String b) {
  final x = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final y = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

class ReleaseFile {
  final String name;
  final int bytes;
  final String sha256;
  const ReleaseFile(this.name, this.bytes, this.sha256);
}

class ReleaseBundle {
  final String contentVersion;
  final int schema;
  final String date;
  final Map<String, ReleaseFile> files;
  const ReleaseBundle({required this.contentVersion, required this.schema, required this.date, required this.files});

  /// Throws [FormatException] on anything that is not a bundle.json.
  static ReleaseBundle parse(String text) {
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic>) throw const FormatException('bundle.json: not a JSON object');
    try {
      final files = (j['files'] as Map<String, dynamic>).map((name, v) => MapEntry(name, ReleaseFile(name, (v as Map<String, dynamic>)['bytes'] as int, v['sha256'] as String)));
      return ReleaseBundle(contentVersion: j['content_version'] as String, schema: int.parse('${j['schema_version']}'), date: (j['content_date'] ?? '') as String, files: files);
    } on TypeError catch (e) {
      throw FormatException('bundle.json: $e');
    }
  }

  ReleaseFile _need(String name) => files[name] ?? (throw FormatException('bundle.json has no $name'));

  /// The database, as served (gzipped) and as it is once inflated.
  ReleaseFile get dbGz => _need('grammar.db.gz');
  ReleaseFile get db => _need('grammar.db');

  /// The illustrations, optional in principle (the lessons work without them).
  ReleaseFile? get images => files['grammar.images'];

  /// Bytes to download for a full install.
  int get downloadBytes => dbGz.bytes + (images?.bytes ?? 0);
}
