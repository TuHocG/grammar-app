/// Choosing where grammar.db and the media folders are, shared by the first-run page and
/// Cài Đặt → Dữ liệu.
///
/// The user picks the data folder (grammar.db and grammar-images.zip side by side), not the
/// file: Android's file picker would hand back a temporary copy of the file in the app cache,
/// without the files around it, that can be cleared at any time.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/image_pack.dart';
import '../../data/media_locations.dart';

/// The data folder the user chose, or null when cancelled. It may hold no grammar.db;
/// callers check.
Future<String?> pickDataFolder(BuildContext context, {String? initialDirectory}) =>
    pickFolder(context, title: 'Chọn thư mục dữ liệu (chứa grammar.db)', initialDirectory: initialDirectory);

/// A media folder (audio, video); null when cancelled.
Future<String?> pickFolder(BuildContext context, {required String title, String? initialDirectory}) =>
    FilePicker.getDirectoryPath(dialogTitle: title, initialDirectory: initialDirectory);

const pickDataLabel = 'Chọn thư mục dữ liệu…';

/// What the data folder holds, for the confirmation before using it.
String describeImages(String dir) {
  final ImagePack? pack;
  try {
    pack = ImagePack.open(p.join(dir, imagePackName));
  } on FormatException {
    return '$imagePackName bị hỏng (có thể tải chưa xong): bài đọc sẽ không có ảnh minh hoạ cho tới khi bạn tải lại file này.';
  }
  if (pack != null) {
    final n = pack.length;
    pack.close();
    return 'Có $imagePackName: $n ảnh minh hoạ.';
  }
  if (Directory(illustrationsDir(dir)).existsSync()) return 'Có thư mục ảnh minh hoạ img/.';
  return 'Không thấy $imagePackName: bài đọc sẽ không có ảnh minh hoạ (ảnh Từ Vựng Tranh nằm sẵn trong grammar.db).';
}
