/// Where the desktop and mobile apps find their content files, and short summaries of what is
/// there (Cài Đặt → Dữ liệu). Everything here is about a folder on disk (`folder_media.dart`);
/// the shared pieces (the setting keys, [audioFor]) are in `media_store.dart`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'content_db.dart';
import 'content_db_io.dart';
import 'content_db_more.dart';
import 'media_store.dart';
import 'models.dart';
import 'user_db.dart';

export 'bytes.dart';
export 'media_store.dart' show audioDirKey, videoDirKey;

/// `audio/` next to grammar.db (release bundle), or `dataset/audio/` (repo content/ folder).
String defaultAudioDir(ContentDb db) => db.folder.defaultAudioDir;

/// `video/` next to grammar.db, or `dataset/video/` (repo content/ folder).
String defaultVideoDir(ContentDb db) => db.folder.defaultVideoDir;

/// Illustrations folder: `img/` next to grammar.db, or `dataset/img/` in the repo.
String illustrationsDir(String dataDir) {
  final release = p.join(dataDir, 'img');
  final repo = p.join(dataDir, 'dataset', 'img');
  if (!Directory(release).existsSync() && Directory(repo).existsSync()) return repo;
  return release;
}

String audioDir(ContentDb db, UserDb user) {
  final s = user.setting(audioDirKey);
  return (s == null || s.isEmpty) ? defaultAudioDir(db) : s;
}

String videoDir(ContentDb db, UserDb user) {
  final s = user.setting(videoDirKey);
  return (s == null || s.isEmpty) ? defaultVideoDir(db) : s;
}

/// Finds the video file of an episode inside [dir]: "A 01.mp4", then the old "A  1.avi"
/// spelling, then any file starting with the code (the old app accepted "F  1 Beauty….avi").
File? findVideoFile(String dir, SubtitleFilm f, [List<FileSystemEntity>? listing]) {
  final d = Directory(dir);
  if (!d.existsSync()) return null;
  for (final c in [f.mp4Name, f.video, f.mp4Name.replaceAll('.mp4', '.avi')]) {
    final file = File(p.join(dir, c));
    if (file.existsSync()) return file;
  }
  final parts = f.code.split(' ');
  final re = RegExp('^${parts[0]}\\s+0*${parts[1]}(\\D|\$)', caseSensitive: false);
  for (final e in listing ?? d.listSync()) {
    if (e is File && re.hasMatch(p.basename(e.path))) return e;
  }
  return null;
}

// ---- summaries ------------------------------------------------------------------------

class DataSummary {
  final String dbPath;
  final int dbBytes;
  final String? version;
  final String? date;
  final int schema;
  final Map<String, dynamic> counts;
  final int images; // illustrations in grammar.images, else files in img/ (or dataset/img/)
  final bool imagePack; // the illustrations come from grammar.images
  final bool imagePackBroken; // grammar.images is there but cannot be read
  final int imagePackBytes;
  final int embedded; // pictures stored inside grammar.db
  const DataSummary({
    required this.dbPath,
    required this.dbBytes,
    this.version,
    this.date,
    required this.schema,
    required this.counts,
    required this.images,
    required this.imagePack,
    this.imagePackBroken = false,
    this.imagePackBytes = 0,
    required this.embedded,
  });
}

DataSummary dataSummary(ContentDb db) {
  final file = File(p.join(db.dataDir, 'grammar.db'));
  final img = Directory(illustrationsDir(db.dataDir));
  final embeddedPaths = <String>{
    if (db.embeddedMediaCount > 0)
      for (final r in db.raw.select('SELECT path FROM media')) r['path'] as String,
  };
  final pack = db.images;
  final images = pack != null
      ? pack.length
      : img.existsSync()
      ? img.listSync(recursive: true).whereType<File>().where((f) => !embeddedPaths.contains('img/${p.posix.joinAll(p.split(p.relative(f.path, from: img.path)))}')).length
      : 0;
  return DataSummary(
    dbPath: file.path,
    dbBytes: file.existsSync() ? file.lengthSync() : 0,
    version: db.contentVersion,
    date: db.contentDate,
    schema: db.schemaVersion,
    counts: db.counts,
    images: images,
    imagePack: pack != null,
    imagePackBroken: db.imagePackError != null,
    imagePackBytes: pack == null ? 0 : File(pack.path).lengthSync(),
    embedded: embeddedPaths.length,
  );
}

class FolderSummary {
  final String dir;
  final bool exists;
  final int found; // items of the content found in the folder
  final int expected; // items the content refers to
  final int bytes;
  const FolderSummary({required this.dir, required this.exists, required this.found, required this.expected, required this.bytes});
}

FolderSummary audioSummary(ContentDb db, String dir) {
  final names = <String>{for (final r in db.raw.select('SELECT audio FROM reading WHERE audio IS NOT NULL')) p.basename(r['audio'] as String)};
  final d = Directory(dir);
  var found = 0, bytes = 0;
  if (d.existsSync()) {
    for (final n in names) {
      final f = File(p.join(dir, n));
      if (f.existsSync()) {
        found++;
        bytes += f.lengthSync();
      }
    }
  }
  return FolderSummary(dir: dir, exists: d.existsSync(), found: found, expected: names.length, bytes: bytes);
}

FolderSummary videoSummary(ContentDb db, String dir) {
  final films = db.films();
  final d = Directory(dir);
  var found = 0, bytes = 0;
  if (d.existsSync()) {
    final listing = d.listSync();
    for (final f in films) {
      final file = findVideoFile(dir, f, listing);
      if (file != null) {
        found++;
        bytes += file.lengthSync();
      }
    }
  }
  return FolderSummary(dir: dir, exists: d.existsSync(), found: found, expected: films.length, bytes: bytes);
}
