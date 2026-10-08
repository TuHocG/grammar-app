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
import '../../platform/storage_access.dart';

/// True when [dbPath] is the picker's temporary copy (chosen by an earlier version on Android).
bool isPickerCopy(String dbPath) => Platform.isAndroid && dbPath.contains('/cache/file_picker/');

/// Explains, then asks for storage access on Android. False when not granted (a message has
/// been shown). Always true elsewhere.
Future<bool> ensureStorageAccess(BuildContext context) async {
  final state = await storageAccess();
  if (state == StorageAccess.granted) return true;
  if (!context.mounted) return false;
  final (next, button) = switch (state) {
    StorageAccess.needsAllFiles => ('Ở trang tiếp theo, hãy bật "Cho phép quản lý tất cả các tệp" cho Grammar 4.0 rồi quay lại app.', 'Tiếp tục'),
    StorageAccess.blocked => ('Quyền này đã bị từ chối. Trong trang cài đặt của app, mở Quyền → Bộ nhớ, chọn Cho phép, rồi quay lại app và bấm chọn lần nữa.', 'Mở cài đặt'),
    _ => ('Hãy chọn Cho phép ở hộp thoại tiếp theo.', 'Tiếp tục'),
  };
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Cho phép đọc thư mục dữ liệu'),
      content: Text(
        'App đọc grammar.db, ảnh, âm thanh và video ngay trong thư mục bạn đã tải về (ví dụ Download/grammar4-data-…), '
        'nên cần quyền truy cập tệp. $next',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Để sau')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(button)),
      ],
    ),
  );
  if (go != true) return false;
  final ok = await requestStorageAccess(state);
  if (!ok && state != StorageAccess.blocked && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có quyền truy cập tệp: app không đọc được thư mục dữ liệu.')));
  }
  return ok;
}

/// The data folder the user chose, or null when cancelled. It may hold no grammar.db;
/// callers check.
Future<String?> pickDataFolder(BuildContext context, {String? initialDirectory}) =>
    pickFolder(context, title: 'Chọn thư mục dữ liệu (chứa grammar.db)', initialDirectory: initialDirectory);

/// A media folder (audio, video); null when cancelled.
Future<String?> pickFolder(BuildContext context, {required String title, String? initialDirectory}) async {
  if (!await ensureStorageAccess(context)) return null;
  return FilePicker.getDirectoryPath(dialogTitle: title, initialDirectory: initialDirectory);
}

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
