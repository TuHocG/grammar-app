/// Read-only access to `grammar.db` (schema: docs/09, built by `python -m etl pack-sqlite`).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'image_pack.dart';
import 'models.dart';

class ContentDb {
  final Database _db;
  final String dataDir;
  ContentDb._(this._db, this.dataDir);

  /// [dataDir] holds `grammar.db` and `grammar-images.zip` (release bundle), or `dataset/img`,
  /// `dataset/audio` (the repo's content/ folder). A release build ships
  /// the database encrypted with SQLite3MultipleCiphers (docs/07 §11); [key] unlocks it.
  /// A plain database (development) opens with or without a key.
  static ContentDb open(String dataDir, {String? key}) {
    final file = p.join(dataDir, 'grammar.db');
    var db = sqlite3.open(file, mode: OpenMode.readOnly);
    if (key != null && key.isNotEmpty) {
      try {
        db.execute("PRAGMA key = '${key.replaceAll("'", "''")}'");
        db.select('SELECT 1 FROM meta LIMIT 1');
      } catch (_) {
        db.close();   // not encrypted (or wrong key): retry as a plain database
        db = sqlite3.open(file, mode: OpenMode.readOnly);
      }
    }
    return ContentDb._(db, dataDir);
  }

  void close() {
    if (_imagesOpened) _images?.close();
    _db.close();
  }

  /// Raw handle for query extensions in other files (read-only database).
  Database get raw => _db;

  /// File of a relative content path (`img/readings/x.webp`, `audio/1.mp3`): `<dir>/img/…` next to
  /// grammar.db in a release bundle, `<dir>/dataset/img/…` in the repo's content/ folder.
  String mediaPath(String rel) {
    final release = p.join(dataDir, rel);
    if (File(release).existsSync()) return release;
    return p.join(dataDir, 'dataset', rel);
  }

  File mediaFile(String rel) => File(mediaPath(rel));

  late final bool _hasMediaTable =
      _db.select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'media'").isNotEmpty;
  final Map<String, Uint8List?> _embedded = {};

  /// Picture stored inside grammar.db (the Từ Vựng Tranh pages), or null.
  Uint8List? embeddedMedia(String rel) {
    if (!_hasMediaTable) return null;
    return _embedded.putIfAbsent(rel, () {
      final rows = _db.select('SELECT data FROM media WHERE path = ?', [rel]);
      return rows.isEmpty ? null : rows.first['data'] as Uint8List;
    });
  }

  int get embeddedMediaCount => _hasMediaTable ? _db.select('SELECT COUNT(*) AS n FROM media').first['n'] as int : 0;

  /// The illustrations zip next to grammar.db, or null (repo layout, not downloaded, or
  /// unreadable: then [imagePackError] says why). Opened on first use.
  ImagePack? get images {
    if (!_imagesOpened) {
      _imagesOpened = true;
      try {
        _images = ImagePack.open(p.join(dataDir, imagePackName));
      } on FormatException catch (e) {
        imagePackError = e.message;
      }
    }
    return _images;
  }
  ImagePack? _images;
  bool _imagesOpened = false;
  String? imagePackError;

  /// Image of a relative content path: the Từ Vựng Tranh pages from the database, the
  /// illustrations from grammar-images.zip, else a file (`img/…` or the repo's `dataset/img/…`).
  ImageProvider imageProvider(String rel) {
    final bytes = embeddedMedia(rel);
    if (bytes != null) return MemoryImage(bytes);
    final pack = images;
    if (pack != null && pack.contains(rel)) return PackImage(pack, rel);
    return FileImage(mediaFile(rel));
  }

  /// Highest `schema_version` of grammar.db this app understands (content/content.json `schema`).
  static const supportedSchema = 1;

  String? _meta(String key) {
    final rows = _db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  /// Databases built before content versioning have no schema key: treat them as schema 1.
  int get schemaVersion => int.tryParse(_meta('schema_version') ?? '') ?? 1;

  /// Content release, e.g. "1.0.0" (content/content.json `version`); null for old databases.
  String? get contentVersion => _meta('content_version');
  String? get contentDate => _meta('content_date');

  Map<String, dynamic> get counts =>
      jsonDecode(_db.select('SELECT value FROM meta WHERE key = ?', ['counts']).first['value'] as String)
          as Map<String, dynamic>;

  // ---- dictionary -------------------------------------------------------

  List<DictHit> searchPrefix(String key, {int limit = 100}) {
    if (key.isEmpty) return const [];
    final hi = '$key￿';
    final rows = _db.select(
      'SELECT id, headword, key, ipa, segs, redirect FROM dict_entry '
      'WHERE key >= ? AND key < ? ORDER BY key, id LIMIT ?',
      [key, hi, limit],
    );
    return [for (final r in rows) _hit(r)];
  }

  /// Entries whose key lies just before [key] in sort order (for "scroll to typed text").
  List<DictHit> around(String key, {int before = 20, int after = 80}) {
    final b = _db.select(
      'SELECT id, headword, key, ipa, segs, redirect FROM dict_entry WHERE key < ? ORDER BY key DESC, id DESC LIMIT ?',
      [key, before],
    );
    final a = _db.select(
      'SELECT id, headword, key, ipa, segs, redirect FROM dict_entry WHERE key >= ? ORDER BY key, id LIMIT ?',
      [key, after],
    );
    return [for (final r in b.toList().reversed) _hit(r), for (final r in a) _hit(r)];
  }

  DictHit _hit(Row r) {
    final e = _entry(r);
    return DictHit(e.id, e.headword, e.key, e.ipa, e.preview);
  }

  DictEntry? entryById(int id) {
    final rows = _db.select('SELECT * FROM dict_entry WHERE id = ?', [id]);
    return rows.isEmpty ? null : _entry(rows.first);
  }

  /// All entries with exactly this key (homographs are separate rows).
  List<DictEntry> entriesByKey(String key) {
    final rows = _db.select('SELECT * FROM dict_entry WHERE key = ? ORDER BY id', [key]);
    return [for (final r in rows) _entry(r)];
  }

  DictEntry _entry(Row r) {
    QuickDef? q;
    final qj = r['quick'];
    if (qj is String && qj.isNotEmpty) {
      final m = jsonDecode(qj) as Map<String, dynamic>;
      q = QuickDef(
        word: r['headword'] as String,
        ipa: m['ipa'] as String?,
        respell: m['rs'] as String?,
        pos: m['pos'] as String?,
        vi: (m['vi'] ?? '') as String,
      );
    }
    return DictEntry(
      id: r['id'] as int,
      headword: r['headword'] as String,
      key: r['key'] as String,
      ipa: r['ipa'] as String?,
      segs: Seg.listFromJson(r['segs'] as String),
      quick: q,
      redirect: r['redirect'] as String?,
    );
  }

  QuickDef? quickDef(String key) {
    final rows = _db.select('SELECT * FROM quick_def WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return QuickDef(
      word: r['word'] as String,
      ipa: r['ipa'] as String?,
      respell: r['respell'] as String?,
      pos: r['pos'] as String?,
      vi: r['vi'] as String,
    );
  }

  bool hasKey(String key) =>
      _db.select('SELECT 1 FROM dict_entry WHERE key = ? LIMIT 1', [key]).isNotEmpty;

  // ---- word forms -------------------------------------------------------

  WordFamily? familyOf(String word) {
    final rows = _db.select(
      'SELECT f.id, f.members FROM wordform_member m JOIN wordform_family f ON f.id = m.family_id '
      'WHERE m.word = ? LIMIT 1',
      [word],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final members = (jsonDecode(r['members'] as String) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => WordForm(e['w'] as String, (e['pos'] ?? '') as String))
        .toList();
    return WordFamily(r['id'] as int, members);
  }

  // ---- help ---------------------------------------------------------------

  List<HelpTopic> helpTopics() => [
        for (final r in _db.select('SELECT id, title, text FROM help_topic ORDER BY id'))
          HelpTopic(r['id'] as int, r['title'] as String, r['text'] as String),
      ];

  HelpTopic? helpTopic(int id) {
    final rows = _db.select('SELECT id, title, text FROM help_topic WHERE id = ?', [id]);
    return rows.isEmpty ? null : HelpTopic(id, rows.first['title'] as String, rows.first['text'] as String);
  }
}

// ---- readings -----------------------------------------------------------------

extension ContentDbReadings on ContentDb {
  /// The whole section tree (root has sid -1).
  ReadingSection sectionTree() {
    final by = <int, ReadingSection>{};
    for (final r in _db.select('SELECT sid, parent_sid, title, depth, position FROM reading_section ORDER BY position')) {
      by[r['sid'] as int] = ReadingSection(
        sid: r['sid'] as int,
        parentSid: r['parent_sid'] as int?,
        title: r['title'] as String,
        depth: r['depth'] as int,
        position: r['position'] as int,
      );
    }
    for (final r in _db.select('SELECT sid, COUNT(*) AS n FROM reading GROUP BY sid')) {
      by[r['sid'] as int]?.readingCount = r['n'] as int;
    }
    ReadingSection? root;
    for (final s in by.values) {
      if (s.parentSid == null) {
        root = s;
      } else {
        by[s.parentSid]?.children.add(s);
      }
    }
    for (final s in by.values) {
      s.children.sort((a, b) => a.position.compareTo(b.position));
    }
    return root ?? ReadingSection(sid: -1, title: 'Bài Đọc', depth: 0, position: 0);
  }

  ReadingSection? section(int sid) {
    final rows = _db.select('SELECT sid, parent_sid, title, depth, position FROM reading_section WHERE sid = ?', [sid]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ReadingSection(sid: sid, parentSid: r['parent_sid'] as int?, title: r['title'] as String, depth: r['depth'] as int, position: r['position'] as int);
  }

  List<ReadingSummary> readingsInSection(int sid) => [
        for (final r in _db.select('SELECT id, sid, position, title, img, audio FROM reading WHERE sid = ? ORDER BY position', [sid]))
          ReadingSummary(
            id: r['id'] as int,
            sid: r['sid'] as int,
            position: r['position'] as int,
            title: r['title'] as String,
            img: r['img'] as String?,
            hasAudio: r['audio'] != null,
          ),
      ];

  List<ReadingSummary> searchReadings(String text, {int limit = 50}) {
    final q = '%${text.trim()}%';
    return [
      for (final r in _db.select('SELECT id, sid, position, title, img, audio FROM reading WHERE title LIKE ? ORDER BY id LIMIT ?', [q, limit]))
        ReadingSummary(id: r['id'] as int, sid: r['sid'] as int, position: r['position'] as int, title: r['title'] as String, img: r['img'] as String?, hasAudio: r['audio'] != null),
    ];
  }

  Reading? reading(int id) {
    final rows = _db.select('SELECT id, sid, position, title, img, audio, times, title_audio, page FROM reading WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final sentences = [
      for (final s in _db.select('SELECT idx, para, en, vi FROM reading_sentence WHERE reading_id = ? ORDER BY idx', [id]))
        // The analysed "Phân Tích Câu" readings keep '|' between word groups (dataPt).
        _sentence(s),
    ];
    List<double>? times;
    if (r['times'] != null) {
      times = (jsonDecode(r['times'] as String) as List).map((e) => (e as num).toDouble()).toList();
    }
    return Reading(
      id: id,
      sid: r['sid'] as int,
      position: r['position'] as int,
      title: r['title'] as String,
      img: r['img'] as String?,
      audio: r['audio'] as String?,
      times: times,
      titleAudio: (r['title_audio'] as int) == 1,
      page: r['page'] as String?,
      sentences: sentences,
    );
  }

  Sentence _sentence(Row s) {
    final en = s['en'] as String;
    final vi = (s['vi'] ?? '') as String;
    if (!en.contains('|')) return Sentence(s['idx'] as int, s['para'] as int, en, vi);
    final tokens = en.split('|').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    return Sentence(s['idx'] as int, s['para'] as int, tokens.join(' '), vi, tokens: tokens);
  }

  /// Previous / next reading in the same section (null at the ends).
  (int? prev, int? next) neighbours(Reading r) {
    final p = _db.select('SELECT id FROM reading WHERE sid = ? AND position < ? ORDER BY position DESC LIMIT 1', [r.sid, r.position]);
    final n = _db.select('SELECT id FROM reading WHERE sid = ? AND position > ? ORDER BY position LIMIT 1', [r.sid, r.position]);
    return (p.isEmpty ? null : p.first['id'] as int, n.isEmpty ? null : n.first['id'] as int);
  }
}

// ---- grammar & exercises ------------------------------------------------------

extension ContentDbGrammar on ContentDb {
  List<GrammarLesson> grammarLessons() => [
        for (final r in _db.select('SELECT ref, title, chapter, drills, body FROM grammar_lesson ORDER BY ref'))
          GrammarLesson(ref: r['ref'] as int, title: r['title'] as String, chapter: (r['chapter'] as int) == 1, drills: (r['drills'] as int) == 1, body: r['body'] as String),
      ];

  GrammarLesson? grammarLesson(int ref) {
    final rows = _db.select('SELECT ref, title, chapter, drills, body FROM grammar_lesson WHERE ref = ?', [ref]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return GrammarLesson(ref: ref, title: r['title'] as String, chapter: (r['chapter'] as int) == 1, drills: (r['drills'] as int) == 1, body: r['body'] as String);
  }

  List<ExerciseMenu> exerciseMenus() => [
        for (final r in _db.select('SELECT idx, name, start, end FROM exercise_menu ORDER BY idx'))
          ExerciseMenu(r['idx'] as int, r['name'] as String, r['start'] as int, r['end'] as int),
      ];

  String? exerciseTitle(int tt, {required bool lessonContext}) {
    final rows = _db.select('SELECT title FROM exercise_title WHERE tt = ? AND context = ?', [tt, lessonContext ? 'lesson' : 'menu']);
    return rows.isEmpty ? null : rows.first['title'] as String;
  }

  /// Exercises by row id range [start, end) (menus are contiguous id ranges).
  List<Exercise> exercisesInRange(int start, int end) => [
        for (final r in _db.select('SELECT * FROM exercise WHERE id >= ? AND id < ? ORDER BY id', [start, end])) _exercise(r),
      ];

  List<Exercise> exercisesForLessons(List<int> refs) {
    if (refs.isEmpty) return const [];
    final q = List.filled(refs.length, '?').join(',');
    return [for (final r in _db.select('SELECT * FROM exercise WHERE lesson_ref IN ($q) ORDER BY id', refs)) _exercise(r)];
  }

  Exercise _exercise(Row r) {
    List<Blank> blanks = const [];
    if (r['blanks'] != null) {
      blanks = [
        for (final b in (jsonDecode(r['blanks'] as String) as List).cast<Map<String, dynamic>>())
          Blank((b['a'] ?? '') as String, ((b['alt'] ?? const []) as List).cast<String>(), (b['n'] ?? 6) as int),
      ];
    }
    List<ExplBlock> expl = const [];
    if (r['expl'] != null) {
      expl = [
        for (final e in (jsonDecode(r['expl'] as String) as List).cast<Map<String, dynamic>>())
          ExplBlock((e['head'] ?? '') as String, ((e['lines'] ?? const []) as List).cast<String>(), ((e['refs'] ?? const []) as List).cast<int>()),
      ];
    }
    return Exercise(
      id: r['id'] as int,
      menu: r['menu'] as int?,
      lessonRef: r['lesson_ref'] as int?,
      g: (r['g'] ?? '') as String,
      kind: r['kind'] as String,
      tt: r['tt'] as int?,
      text: (r['text'] ?? '') as String,
      blanks: blanks,
      given: r['given'] == null ? const [] : (jsonDecode(r['given'] as String) as List).cast<String>(),
      choices: r['choices'] == null ? const [] : (jsonDecode(r['choices'] as String) as List).cast<String>(),
      answer: r['answer'] as String?,
      vi: r['vi'] as String?,
      expl: expl,
      refs: r['refs'] == null ? const [] : (jsonDecode(r['refs'] as String) as List).cast<int>(),
    );
  }

  List<WordformRoot> wordformRoots() => [
        for (final r in _db.select('SELECT position, root, start, count, common FROM wordform_root ORDER BY position'))
          WordformRoot(r['position'] as int, r['root'] as String, r['start'] as int, r['count'] as int, (r['common'] as int) == 1),
      ];
}
