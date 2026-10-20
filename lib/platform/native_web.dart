import 'package:sqlite3/common.dart';

import '../data/media_store.dart';

CommonDatabase openNativeDatabase(String path, {bool readOnly = false}) => throw UnsupportedError('no file system on the web: $path');

MediaStore folderMedia(String dataDir, {String? sharedMediaDir}) => throw UnsupportedError('no file system on the web: $dataDir');
