import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/content_db.dart';
import '../data/user_db.dart';
import '../platform/downloader_io.dart';
import '../ui/setup/setup_page.dart';
import 'grammar_app.dart';
import 'restart.dart';
import 'theme.dart';

/// Development default; override with `--dart-define=GRAMMAR_DATA_DIR=...`.
const _envDataDir = String.fromEnvironment('GRAMMAR_DATA_DIR');

/// Development fallback: the repo's `content/` folder (cwd is the repo root under `flutter run`),
/// once `python3 tool/content/pack.py` has built `content/grammar.db`.
String? _localDataDir() {
  final d = p.join(Directory.current.path, 'content');
  return File(p.join(d, 'grammar.db')).existsSync() ? d : null;
}

late UserDb _userDb;
late Directory _support;

/// The open lesson database; closed shortly after the bootstrap reopens another one.
ContentDb? _content;

/// user.db in the app's support folder, then the data folder (setting, define, repo) → grammar.db.
Future<void> bootstrap() async {
  MediaKit.ensureInitialized();
  _support = await getApplicationSupportDirectory();
  _userDb = UserDb.open(p.join(_support.path, 'user.db'));
  restartApp = () => _start();
  await _start();
}

Future<void> _start({String? error}) async {
  final dir = _userDb.setting('data_dir') ?? (_envDataDir.isNotEmpty ? _envDataDir : null) ?? _localDataDir();
  if (error != null || dir == null || !File(p.join(dir, 'grammar.db')).existsSync()) {
    runApp(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: SetupPage(
          initial: dir ?? _envDataDir,
          error: error,
          onChosen: (d) {
            _userDb.setSetting('data_dir', d);
            _start();
          },
        ),
      ),
    );
    return;
  }
  final previous = _content;
  if (previous != null) {
    // Pages of the old tree may still read it during the frame that swaps the app.
    Future.delayed(const Duration(seconds: 2), previous.close);
    _content = null;
  }
  final ContentDb content;
  final contentRoot = Directory(p.join(_support.path, 'content'));
  try {
    // Data the app downloaded itself: recordings and videos live beside it, not inside the version folder.
    content = ContentDb.open(dir, sharedMediaDir: ContentDownloader.isManaged(contentRoot, dir) ? _support.path : null);
  } catch (e) {
    await _start(
      error:
          'Không mở được grammar.db: $e\n'
          'Nếu đây là grammar.db của bản 1.0.x (mã hoá, bản này không đọc nữa), hãy tải gói dữ liệu mới nhất từ trang phát hành.',
    );
    return;
  }
  if (content.schemaVersion > ContentDb.supportedSchema) {
    final v = content.schemaVersion;
    content.close();
    await _start(error: 'Dữ liệu nội dung dùng lược đồ $v, bản app này chỉ đọc được tới lược đồ ${ContentDb.supportedSchema}. Hãy cập nhật app.');
    return;
  }
  _content = content;
  await startApp(content: content, user: _userDb);
  // What the app downloaded for other versions is not needed once this one is in use.
  unawaited(ContentDownloader.removeOthers(contentRoot, dir).catchError((_) {}));
}
