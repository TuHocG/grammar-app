/// Bài Nhập Của Bạn (docs/08 N1–N5): readings the user writes, stored in user.db.
/// `en`/`vi` are JSON arrays of paragraphs → sentences like content readings; the old app
/// split sentences on `_`, we split on sentence punctuation or an explicit `_`.
library;

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'models.dart';
import 'reading_loader.dart';
import 'user_db.dart';

class UserReading {
  final int id;
  final String package; // group name (old app: folder in BaiNhap)
  final String title;
  final List<List<String>> en;
  final List<List<String>> vi;
  final String? img; // absolute path chosen by the user
  final DateTime createdAt;
  const UserReading({required this.id, required this.package, required this.title, required this.en, required this.vi, this.img, required this.createdAt});

  Reading toReading() {
    final sentences = <Sentence>[];
    var idx = 0;
    for (var p = 0; p < en.length; p++) {
      for (var k = 0; k < en[p].length; k++) {
        final v = p < vi.length && k < vi[p].length ? vi[p][k] : '';
        sentences.add(Sentence(idx++, p, en[p][k], v));
      }
    }
    return Reading(id: userReadingBase + id, sid: -2, position: id, title: title, img: img, titleAudio: false, sentences: sentences);
  }
}

/// Split free text into paragraphs (blank line) and sentences ('_' or . ! ? followed by space
/// and a capital — any script, so Vietnamese "Đ", "Ô" count — a digit or an opening quote).
List<List<String>> splitText(String text) {
  final paras = text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
  final out = <List<String>>[];
  for (final p in paras) {
    final flat = p.replaceAll('\n', ' ').trim();
    if (flat.isEmpty) continue;
    final parts = flat.contains('_') ? flat.split('_') : flat.split(RegExp(r'(?<=[.!?])\s+(?=[\p{Lu}\d"“‘(])', unicode: true));
    final sents = parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (sents.isNotEmpty) out.add(sents);
  }
  return out;
}

extension UserReadings on UserDb {
  List<UserReading> userReadings({String? package}) => [
    for (final r in raw.select(
      package == null ? 'SELECT * FROM user_reading ORDER BY package, id' : 'SELECT * FROM user_reading WHERE package = ? ORDER BY id',
      package == null ? const [] : [package],
    ))
      _ur(r),
  ];

  List<String> userReadingPackages() => [for (final r in raw.select('SELECT DISTINCT package FROM user_reading ORDER BY package')) r['package'] as String];

  UserReading? userReading(int id) {
    final rows = raw.select('SELECT * FROM user_reading WHERE id = ?', [id]);
    return rows.isEmpty ? null : _ur(rows.first);
  }

  int insertUserReading({required String package, required String title, required List<List<String>> en, required List<List<String>> vi, String? img}) {
    raw.execute('INSERT INTO user_reading(package, title, en, vi, img, created_at) VALUES (?, ?, ?, ?, ?, ?)', [
      package,
      title,
      jsonEncode(en),
      jsonEncode(vi),
      img,
      DateTime.now().millisecondsSinceEpoch,
    ]);
    return raw.lastInsertRowId;
  }

  void updateUserReading(int id, {required String package, required String title, required List<List<String>> en, required List<List<String>> vi, String? img}) {
    raw.execute('UPDATE user_reading SET package = ?, title = ?, en = ?, vi = ?, img = ? WHERE id = ?', [package, title, jsonEncode(en), jsonEncode(vi), img, id]);
  }

  void deleteUserReading(int id) => raw.execute('DELETE FROM user_reading WHERE id = ?', [id]);

  UserReading _ur(Row r) => UserReading(
    id: r['id'] as int,
    package: r['package'] as String,
    title: r['title'] as String,
    en: (jsonDecode(r['en'] as String) as List).map((p) => (p as List).cast<String>()).toList(),
    vi: (jsonDecode(r['vi'] as String) as List).map((p) => (p as List).cast<String>()).toList(),
    img: r['img'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );
}
