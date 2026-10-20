/// The [MediaStore] of the desktop and mobile apps: the folder holding grammar.db.
///
/// - Illustrations: entries of `grammar.images` next to grammar.db (release), else files under
///   `img/` next to it, else `dataset/img/` (the repo's content/ folder).
/// - Recordings (Âm thanh thực): `audio/` next to grammar.db, else `dataset/audio/`, unless the
///   user picked another folder. Files are named as in the readings (`1.mp3`, `2.mp3` …).
/// - Videos: `video/` next to grammar.db, else `dataset/video/`; files `A 01.mp4` … (or the
///   old `A  1.avi`). The video pages resolve the files themselves (`media_locations.dart`).
library;

import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'image_pack.dart';
import 'media_store.dart';

class FolderMediaStore implements MediaStore {
  /// The folder holding grammar.db.
  final String dataDir;
  FolderMediaStore(this.dataDir);

  /// `<name>/` next to grammar.db (release bundle), or `dataset/<name>/` (repo content/ folder).
  String besideData(String name) {
    final release = p.join(dataDir, name);
    final repo = p.join(dataDir, 'dataset', name);
    if (!Directory(release).existsSync() && Directory(repo).existsSync()) return repo;
    return release;
  }

  String get defaultAudioDir => besideData('audio');
  String get defaultVideoDir => besideData('video');

  /// File of a relative content path (`img/readings/x.webp`, `audio/1.mp3`): `<dir>/img/…` next to
  /// grammar.db in a release bundle, `<dir>/dataset/img/…` in the repo's content/ folder.
  String mediaPath(String rel) {
    final release = p.join(dataDir, rel);
    if (File(release).existsSync()) return release;
    return p.join(dataDir, 'dataset', rel);
  }

  File mediaFile(String rel) => File(mediaPath(rel));

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

  @override
  void close() {
    if (_imagesOpened) _images?.close();
  }

  @override
  ImageProvider image(String rel) {
    final pack = images;
    if (pack != null && pack.contains(rel)) return PackImage(pack, rel);
    return FileImage(mediaFile(rel));
  }

  @override
  AudioRef? audio(String rel, {String? dir}) {
    final folder = (dir == null || dir.isEmpty) ? defaultAudioDir : dir;
    final path = p.join(folder, p.basename(rel));
    return File(path).existsSync() ? AudioFile(path) : null;
  }
}
