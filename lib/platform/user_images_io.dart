import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The picture stored under [ref] (`user_reading.img`): a file path.
ImageProvider userImage(String ref) => FileImage(File(ref));

bool userImageExists(String ref) => File(ref).existsSync();

/// Lets the user pick a picture; the value to store in `user_reading.img`, or null when they
/// picked nothing. [current] is the stored value, to start the dialog in its folder.
Future<String?> pickUserImage({required String current}) async {
  final files = await FilePicker.pickFiles(dialogTitle: 'Chọn ảnh đầu bài', type: FileType.image, initialDirectory: current.isEmpty ? null : File(current).parent.path);
  final picked = files.isEmpty ? null : files.first.path;
  if (picked == null) return null;
  return _keepImage(picked);
}

/// On Android and iOS the picker hands back a temporary copy (app cache / tmp) that the OS
/// may clear, so keep our own copy under app support; desktop paths are the user's file.
Future<String> _keepImage(String picked) async {
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return picked;
  final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'user_images'));
  await dir.create(recursive: true);
  final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(picked)}');
  await File(picked).copy(dest);
  return dest;
}
