/// The content folder behind a [ContentDb] opened with [ContentDb.open] (desktop and mobile):
/// grammar.db, grammar.images and the media folders next to it. Not for the web build.
library;

import 'dart:io';

import 'content_db.dart';
import 'folder_media.dart';
import 'image_pack.dart';

extension ContentDbFolder on ContentDb {
  FolderMediaStore get folder => media is FolderMediaStore ? media as FolderMediaStore : throw StateError('this ContentDb was not opened from a folder (ContentDb.open)');

  /// The folder holding grammar.db.
  String get dataDir => folder.dataDir;

  ImagePack? get images => folder.images;
  String? get imagePackError => folder.imagePackError;
  String mediaPath(String rel) => folder.mediaPath(rel);
  File mediaFile(String rel) => folder.mediaFile(rel);
}
