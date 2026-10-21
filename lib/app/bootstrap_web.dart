import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqlite3/wasm.dart';

import '../data/block_vfs.dart';
import '../data/content_db.dart';
import '../data/manifest.dart';
import '../data/user_db.dart';
import '../data/web_media.dart';
import '../platform/web_download.dart';
import '../platform/web_store.dart';
import '../ui/setup/web_setup_page.dart';
import 'grammar_app.dart';
import 'restart.dart';
import 'theme.dart';
import 'updates.dart';

/// The web app (docs/07 §12): SQLite compiled to WebAssembly; user.db in IndexedDB; the content
/// database downloaded once into Cache Storage and read through [BlockVfs]; pictures fetched
/// from the host as they are opened.
Future<void> bootstrap() async {
  restartApp = () => unawaited(_start());
  await _start();
}

final _host = HostLocation.ofApp();
WasmSqlite3? _sqlite;
UserDb? _user;
ContentDb? _content;
BlockVfs? _vfs;

Future<void> _start() async {
  try {
    if (_user == null && !await acquireSessionLock('grammar4')) {
      _note('Grammar đang mở ở một thẻ khác của trình duyệt. Hãy dùng thẻ đó, hoặc đóng nó rồi tải lại trang này.');
      return;
    }
    final sqlite = _sqlite ??= await WasmSqlite3.loadFromUrl(Uri.base.resolve('sqlite3.wasm'));
    final user = _user ??= await _openUserDb(sqlite);

    var installed = await loadInstalled(_host);
    if (installed == null) {
      // First visit: the current version is the one to download.
      final HostContent current;
      try {
        current = await fetchLatest(_host);
      } on HostUnreachable {
        _note('Lần đầu mở cần có mạng để tải bài học (khoảng 60 MB). Hãy kết nối mạng rồi tải lại trang.');
        return;
      }
      if (current.$2.schema > ContentDb.supportedSchema) {
        _note('Dữ liệu trên máy chủ dùng lược đồ ${current.$2.schema}, bản app này chỉ đọc được tới lược đồ ${ContentDb.supportedSchema}. Tải lại trang để lấy bản app mới.');
        return;
      }
      if (await cachedPacks(current.$2, _host) == null) {
        runApp(_app(WebSetupPage(latest: current.$1, manifest: current.$2, host: _host, onDone: _start)));
        return;
      }
      await markInstalled(_host, current.$1); // only the pointer was lost: nothing to download
      installed = current;
    }
    final (latest, manifest) = installed;
    final packs = await cachedPacks(manifest, _host);
    if (packs == null) {
      // The installed pointer is there but a pack is gone (evicted): download again.
      runApp(_app(WebSetupPage(latest: latest, manifest: manifest, host: _host, onDone: _start)));
      return;
    }
    final previous = (_content, _vfs);
    final vfs = BlockVfs(PackedBlockSource(manifest.db, packs));
    final content = ContentDb.fromDatabase(vfs.open(sqlite), media: WebMediaStore(_host, manifest, recordings: await cachedUrls(audioCache).catchError((Object _) => <String>[])));
    _content = content;
    _vfs = vfs;
    if (previous case (final c?, final v?)) {
      // Pages of the old tree may still read it during the frame that swaps the app.
      Future.delayed(const Duration(seconds: 2), () {
        c.close();
        v.close();
      });
    }
    availableContentUpdate.value = null;
    await startApp(content: content, user: user);
    unawaited(_afterStart(latest, manifest));
  } on FormatException catch (e) {
    _note('Không đọc được dữ liệu trên máy chủ: ${e.message}. Tải lại trang để lấy bản app mới.');
  } catch (e) {
    _note('Không khởi động được: $e\nHãy tải lại trang; nếu vẫn vậy, trình duyệt này có thể không cho lưu dữ liệu (chế độ riêng tư?).');
  }
}

/// user.db on an IndexedDB-backed file system: the whole file in memory, written back in the
/// background and on every hide of the page.
Future<UserDb> _openUserDb(WasmSqlite3 sqlite) async {
  final fs = await IndexedDbFileSystem.open(dbName: 'grammar4');
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  final user = UserDb.fromDatabase(sqlite.open('/user.db'));
  onPageHide(() => unawaited(fs.flush()));
  return user;
}

/// Housekeeping once the app is up: keep the storage, fetch the Từ Vựng Tranh pages so that
/// section works offline, and look for newer content.
Future<void> _afterStart(HostLatest latest, HostManifest manifest) async {
  try {
    if (!await storagePersisted()) await persistStorage();
    if (!onLine) return;
    await prefetchImages(manifest, _host, picturePages(manifest));
    final (newer, m) = await fetchLatest(_host);
    if (newer.version != latest.version && m.schema <= ContentDb.supportedSchema) availableContentUpdate.value = newer.version;
  } catch (_) {
    // Nothing the user needs to hear about; Cài Đặt → Dữ liệu checks on demand.
  }
}

void _note(String text) => runApp(
  _app(
    Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SelectableText(text, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  ),
);

Widget _app(Widget home) => MaterialApp(title: 'Grammar 4.0', theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), home: home);
