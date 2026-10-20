import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/folder_media.dart';
import '../data/media_store.dart';

/// Opens a database file through the native SQLite library.
CommonDatabase openNativeDatabase(String path, {bool readOnly = false}) => sqlite3.open(path, mode: readOnly ? OpenMode.readOnly : OpenMode.readWriteCreate);

/// The pictures and recordings next to `<dataDir>/grammar.db`.
MediaStore folderMedia(String dataDir) => FolderMediaStore(dataDir);
