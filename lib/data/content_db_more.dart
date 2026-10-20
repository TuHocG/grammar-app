/// Queries for dialogs, listening, video subtitles, sentence analysis and pictures.
library;

import 'dart:convert';

import 'package:sqlite3/common.dart';

import 'content_db.dart';
import 'models.dart';

extension ContentDbMore on ContentDb {
  List<DialogTopic> dialogTopics() => [
    for (final r in raw.select('SELECT sid, title, position FROM dialog_topic ORDER BY position')) DialogTopic(r['sid'] as int, r['title'] as String, r['position'] as int),
  ];

  DialogTopic? dialogTopic(int sid) {
    final rows = raw.select('SELECT sid, title, position FROM dialog_topic WHERE sid = ?', [sid]);
    return rows.isEmpty ? null : DialogTopic(sid, rows.first['title'] as String, rows.first['position'] as int);
  }

  List<Dialog> dialogsInTopic(int sid) => [
    for (final r in raw.select('SELECT * FROM dialog WHERE sid = ? ORDER BY position', [sid])) _dialog(r),
  ];

  Dialog? dialog(int id) {
    final rows = raw.select('SELECT * FROM dialog WHERE id = ?', [id]);
    return rows.isEmpty ? null : _dialog(rows.first);
  }

  /// Topic of a dialog id (for pick badges).
  int? dialogTopicOf(int dialogId) {
    final rows = raw.select('SELECT sid FROM dialog WHERE id = ?', [dialogId]);
    return rows.isEmpty ? null : rows.first['sid'] as int;
  }

  Dialog _dialog(Row r) => Dialog(
    id: r['id'] as int,
    sid: r['sid'] as int,
    position: r['position'] as int,
    title: r['title'] as String,
    pairs: [
      for (final p in (jsonDecode(r['pairs'] as String) as List).cast<Map<String, dynamic>>())
        DialogPair((p['a'] ?? '') as String, (p['b'] ?? '') as String, (p['avi'] ?? '') as String, (p['bvi'] ?? '') as String),
    ],
  );

  List<String> dialogImages() {
    final rows = raw.select('SELECT value FROM meta WHERE key = ?', ['dialog_images']);
    return rows.isEmpty ? const [] : (jsonDecode(rows.first['value'] as String) as List).cast<String>();
  }

  /// Illustrations of the Luyện Nói pages (Pic2/CANBAN1..24, random in the old app).
  List<String> dialogPageImages() {
    final rows = raw.select('SELECT value FROM meta WHERE key = ?', ['dialog_page_images']);
    return rows.isEmpty ? const [] : (jsonDecode(rows.first['value'] as String) as List).cast<String>();
  }

  /// One of [dialogPageImages], fixed per number so a topic/dialog keeps its picture.
  String? dialogPageImage(int n) {
    final pool = dialogPageImages();
    return pool.isEmpty ? null : pool[n % pool.length];
  }

  /// Luyện Nghe unit u plays `sound/u.*`, i.e. the recording of the "Các Bài Âm Thanh
  /// Thực" reading with that file (READING.bas:TinhTenBaiSoundThuc, Butcu = 4); item n is
  /// sentence n of that reading (AmthanhThuc.bas:SoundThuc1Cau). Null when no recording.
  Reading? listeningReading(int unit) {
    final rows = raw.select("SELECT id FROM reading WHERE audio LIKE ? ORDER BY id LIMIT 1", ['audio/$unit.%']);
    return rows.isEmpty ? null : reading(rows.first['id'] as int);
  }

  /// Id and title of [listeningReading], without loading its sentences (unit list, headers).
  ({int id, String title})? listeningReadingTitle(int unit) {
    final rows = raw.select("SELECT id, title FROM reading WHERE audio LIKE ? ORDER BY id LIMIT 1", ['audio/$unit.%']);
    return rows.isEmpty ? null : (id: rows.first['id'] as int, title: rows.first['title'] as String);
  }

  List<int> listeningUnits() => [for (final r in raw.select('SELECT DISTINCT unit FROM listening_item ORDER BY unit')) r['unit'] as int];

  int listeningCount(int unit) => raw.select('SELECT COUNT(*) AS n FROM listening_item WHERE unit = ?', [unit]).first['n'] as int;

  List<ListeningItem> listeningItems(int unit) => [
    for (final r in raw.select('SELECT * FROM listening_item WHERE unit = ? ORDER BY n, id', [unit]))
      ListeningItem(
        id: r['id'] as int,
        unit: r['unit'] as int,
        n: r['n'] as int,
        en: r['en'] as String,
        correct: r['correct'] as String,
        options: (jsonDecode(r['options'] as String) as List).cast<String>(),
      ),
  ];

  List<SubtitleFilm> films() => [for (final r in raw.select('SELECT * FROM subtitle_film ORDER BY id')) _film(r)];

  SubtitleFilm? film(int id) {
    final rows = raw.select('SELECT * FROM subtitle_film WHERE id = ?', [id]);
    return rows.isEmpty ? null : _film(rows.first);
  }

  SubtitleFilm _film(Row r) => SubtitleFilm(
    id: r['id'] as int,
    code: r['code'] as String,
    group: r['grp'] as String,
    title: r['title'] as String,
    firstLine: r['first_line'] as String?,
    video: r['video'] as String,
    duration: (r['duration'] as num).toDouble(),
    lines: r['lines'] as int,
  );

  List<SubtitleLine> subtitleLines(int filmId) => [
    for (final r in raw.select('SELECT idx, s, e, en, vi FROM subtitle_line WHERE film_id = ? ORDER BY idx', [filmId]))
      SubtitleLine(r['idx'] as int, (r['s'] as num).toDouble(), (r['e'] as num).toDouble(), r['en'] as String, (r['vi'] ?? '') as String),
  ];

  List<int> analysisLessonIds() => [for (final r in raw.select('SELECT id FROM analysis_lesson ORDER BY id')) r['id'] as int];

  List<AnalysisWord> analysisWords(int id) {
    final rows = raw.select('SELECT words FROM analysis_lesson WHERE id = ?', [id]);
    if (rows.isEmpty) return const [];
    return [
      for (final w in (jsonDecode(rows.first['words'] as String) as List).cast<Map<String, dynamic>>())
        AnalysisWord(
          n: (w['n'] ?? '').toString(),
          word: (w['word'] ?? '') as String,
          pos: (w['pos'] ?? '') as String,
          position: (w['position'] ?? '') as String,
          function: (w['function'] ?? '') as String,
          meaning: (w['meaning'] ?? '') as String,
          note: (w['note'] ?? '') as String,
          refs: ((w['refs'] ?? const []) as List).cast<int>(),
        ),
    ];
  }

  List<PictureTopic> pictureTopics() => [for (final r in raw.select('SELECT * FROM picture_topic ORDER BY id')) _topic(r)];

  PictureTopic? pictureTopic(int id) {
    final rows = raw.select('SELECT * FROM picture_topic WHERE id = ?', [id]);
    return rows.isEmpty ? null : _topic(rows.first);
  }

  PictureTopic _topic(Row r) => PictureTopic(
    id: r['id'] as int,
    title: r['title'] as String,
    first: r['first'] as int,
    page: r['page'] as String?,
    words: [
      for (final w in (jsonDecode(r['words'] as String) as List).cast<Map<String, dynamic>>())
        PictureWord((w['en'] ?? '') as String, (w['vi'] ?? '') as String, w['xy'] == null ? null : (w['xy'] as List)[0] as int, w['xy'] == null ? null : (w['xy'] as List)[1] as int),
    ],
  );
}
