/// Downloads a data release into the app's own folder on the desktop and mobile apps (docs/07
/// §12): `bundle.json` says what to fetch, each file goes to a `.part` that resumes with a Range
/// request, is checked against its sha256, and the gzipped database is inflated into place.
/// Each content version gets its own folder, so a download never touches the database in use.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/content_db.dart';
import '../data/download_progress.dart';
import '../data/release_bundle.dart';

/// The release needs a newer app.
class UnsupportedContent implements Exception {
  final int schema;
  const UnsupportedContent(this.schema);
  @override
  String toString() => 'Dữ liệu này dùng lược đồ $schema, bản app chỉ đọc được tới ${ContentDb.supportedSchema}. Hãy cập nhật app.';
}

/// A file that did not arrive whole or does not match the release.
class DownloadFailure implements Exception {
  final String message;
  const DownloadFailure(this.message);
  @override
  String toString() => message;
}

/// [ContentDownloader.cancel] was called.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => 'Đã dừng tải.';
}

/// Files the downloader writes; nothing else in a version folder is its to delete.
const _ownedNames = {'grammar.db', 'grammar.images', 'grammar.db.gz'};
const _ownedSuffixes = ['.part', '.tmp'];

class ContentDownloader {
  /// Where `bundle.json` is looked up (a URL ending with `/`).
  final Uri source;

  /// `<app support>/content`: one sub-folder per content version.
  final Directory root;

  /// Where the files of the bundle in hand are fetched from: `source`, or the release folder its
  /// `bundle.json` redirected to (`releases/latest/…` may point at a newer release by the time the
  /// files are fetched; the files must come from the same release as the bundle).
  Uri _base;
  HttpClient _http = _client();
  int _generation = 0;
  bool _running = false;

  ContentDownloader({required this.source, required this.root}) : _base = source;

  static HttpClient _client() => HttpClient()
    ..userAgent = 'Grammar4'
    ..autoUncompress =
        false // sizes and hashes are those of the files as published
    ..connectionTimeout = const Duration(seconds: 15);

  /// The app's own data folder, `<app support>/content`.
  static Future<Directory> appRoot() async => Directory(p.join((await getApplicationSupportDirectory()).path, 'content'));

  /// A downloader into [appRoot].
  static Future<ContentDownloader> forApp(Uri source) async => ContentDownloader(source: source, root: await appRoot());

  /// Whether [dir] is a version folder under [root] (data the app downloaded itself).
  static bool isManaged(Directory root, String dir) => p.isWithin(p.canonicalize(root.path), p.canonicalize(dir));

  Future<ReleaseBundle> fetchBundle() async {
    final res = await (await _http.getUrl(source.resolve('bundle.json'))).close();
    if (res.statusCode != HttpStatus.ok) throw DownloadFailure('bundle.json: HTTP ${res.statusCode}');
    final text = await res.transform(utf8.decoder).join();
    // The last hop still on the release host names the release folder (github.com/…/releases/download/<tag>/).
    final onHost = res.redirects.map((r) => r.location).where((u) => u.host.isEmpty || u.host == source.host).toList();
    _base = onHost.isEmpty ? source : source.resolveUri(onHost.last).resolve('.');
    final b = ReleaseBundle.parse(text);
    if (b.schema > ContentDb.supportedSchema) throw UnsupportedContent(b.schema);
    return b;
  }

  /// Downloads and verifies the files of [b] into `root/<version>/`; the data folder to use.
  /// Throws [DownloadFailure], [DownloadCancelled], or an I/O error; what arrived stays for a
  /// later resume.
  Future<String> install(ReleaseBundle b, {void Function(DownloadProgress)? onProgress}) async {
    if (_running) throw StateError('a download is running');
    _running = true;
    final gen = ++_generation;
    try {
      final dir = Directory(p.join(root.path, b.contentVersion));
      await dir.create(recursive: true);
      final total = b.downloadBytes;
      var done = 0;
      void report(int got, String? item) => onProgress?.call(DownloadProgress(done + got, total, item));

      final db = File(p.join(dir.path, 'grammar.db'));
      if (!await _matches(db, b.db)) {
        final gz = File(p.join(dir.path, 'grammar.db.gz'));
        await _fetch(gen, b.dbGz, gz, (got) => report(got, b.dbGz.name));
        done += b.dbGz.bytes;
        report(0, 'grammar.db');
        final tmp = File('${db.path}.tmp');
        await gz.openRead().transform(gzip.decoder).pipe(tmp.openWrite());
        _check(gen);
        if (!await _matches(tmp, b.db)) {
          await tmp.delete();
          await gz.delete();
          throw const DownloadFailure('grammar.db giải nén ra không khớp với bản phát hành; hãy tải lại.');
        }
        await tmp.rename(db.path);
        await gz.delete();
      } else {
        done += b.dbGz.bytes;
      }

      final img = b.images;
      if (img != null) {
        await _fetch(gen, img, File(p.join(dir.path, img.name)), (got) => report(got, img.name));
        done += img.bytes;
      }
      report(0, null);
      return dir.path;
    } finally {
      _running = false;
    }
  }

  /// Stops the download in progress at once; what arrived stays for a later resume.
  void cancel() {
    _generation++;
    _http.close(force: true);
    _http = _client();
  }

  void _check(int gen) {
    if (gen != _generation) throw const DownloadCancelled();
  }

  /// Removes, under [root], what the downloader wrote in version folders other than [keep] (the
  /// data folder in use). A folder with a download under way (`.part`) is left alone, and so is
  /// anything the user put there (recordings, videos).
  static Future<void> removeOthers(Directory root, String? keep) async {
    if (!await root.exists()) return;
    await for (final e in root.list()) {
      if (e is! Directory || (keep != null && p.canonicalize(e.path) == p.canonicalize(keep))) continue;
      final files = await e.list().toList();
      if (files.any((f) => f.path.endsWith('.part'))) continue;
      for (final f in files) {
        final name = p.basename(f.path);
        if (f is File && (_ownedNames.contains(name) || _ownedSuffixes.any(name.endsWith))) await f.delete();
      }
      if (await e.list().isEmpty) await e.delete();
    }
  }

  /// Downloads [f] to [target] through `<target>.part`, resuming what is there, and verifies it.
  /// Nothing to do when [target] already matches.
  Future<void> _fetch(int gen, ReleaseFile f, File target, void Function(int got) onBytes) async {
    if (await _matches(target, f)) return;
    final part = File('${target.path}.part');
    var have = await part.exists() ? await part.length() : 0;
    if (have > f.bytes) {
      await part.delete();
      have = 0;
    }
    if (have < f.bytes) {
      final HttpClientResponse res;
      try {
        final req = await _http.getUrl(_base.resolve(f.name));
        if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
        res = await req.close();
      } catch (e) {
        _check(gen);
        rethrow;
      }
      final resumed = res.statusCode == HttpStatus.partialContent;
      if (res.statusCode != HttpStatus.ok && !resumed) throw DownloadFailure('${f.name}: HTTP ${res.statusCode}');
      if (!resumed) have = 0; // the server sent the whole file: start over
      final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in res.timeout(const Duration(seconds: 30))) {
          _check(gen);
          sink.add(chunk);
          have += chunk.length;
          onBytes(have);
        }
      } on DownloadCancelled {
        rethrow;
      } catch (e) {
        _check(gen);
        throw DownloadFailure('${f.name}: kết nối bị ngắt sau ${have ~/ 1024} KB; bấm Tải tiếp để tải nốt.');
      } finally {
        await sink.close();
      }
      // A connection that closed early may end the stream like a complete one: keep what arrived.
      if (have < f.bytes) throw DownloadFailure('${f.name}: kết nối bị ngắt sau ${have ~/ 1024} KB; bấm Tải tiếp để tải nốt.');
    }
    if (!await _matches(part, f)) {
      await part.delete();
      throw DownloadFailure('${f.name} tải về không khớp với bản phát hành (mạng chập chờn, hoặc máy chủ vừa có bản mới?); hãy kiểm tra lại.');
    }
    await part.rename(target.path);
  }

  Future<bool> _matches(File file, ReleaseFile f) async {
    if (!await file.exists() || await file.length() != f.bytes) return false;
    return (await sha256.bind(file.openRead()).first).toString() == f.sha256;
  }

  void close() => _http.close(force: true);
}
