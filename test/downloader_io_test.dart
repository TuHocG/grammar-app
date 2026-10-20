// The native downloader (lib/platform/downloader_io.dart) against a local server: a full
// download, a connection cut half-way that resumes with a Range request, a corrupted file, and
// a release that needs a newer app.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/release_bundle.dart';
import 'package:grammar/platform/downloader_io.dart';
import 'package:sqlite3/sqlite3.dart';

/// A tiny grammar.db: just the meta table the app probes.
Uint8List makeDb(Directory tmp) {
  final path = '${tmp.path}/src.db';
  final db = sqlite3.open(path);
  db.execute("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL); INSERT INTO meta VALUES ('schema_version', '1'), ('content_version', '9.9.9');");
  db.close();
  return File(path).readAsBytesSync();
}

class FakeRelease {
  final Map<String, Uint8List> files = {};
  HttpServer? server;

  /// Close the connection after this many bytes of a file, once (null: never).
  int? cutAfter;
  final rangeRequests = <String>[];

  Uri get url => Uri.parse('http://127.0.0.1:${server!.port}/');

  Future<void> start(Uint8List db, {int schema = 1, bool corruptImages = false}) async {
    final gz = Uint8List.fromList(gzip.encode(db));
    final images = Uint8List.fromList(List.generate(300000, (i) => i % 251));
    files['grammar.db.gz'] = gz;
    files['grammar.images'] = images;
    String sha(List<int> b) => sha256.convert(b).toString();
    files['bundle.json'] = utf8.encode(
      jsonEncode({
        'content_version': '9.9.9',
        'schema_version': '$schema',
        'content_date': '2026-10-20',
        'files': {
          'grammar.db': {'bytes': db.length, 'sha256': sha(db)},
          'grammar.db.gz': {'bytes': gz.length, 'sha256': sha(gz)},
          'grammar.images': {'bytes': images.length, 'sha256': corruptImages ? 'bad' : sha(images)},
        },
      }),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((req) async {
      final name = req.uri.pathSegments.last;
      final body = files[name];
      if (body == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      var start = 0;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        rangeRequests.add('$name $range');
        start = int.parse(range.substring('bytes='.length, range.length - 1));
      }
      final cut = cutAfter;
      if (cut != null && name != 'bundle.json' && body.length - start > cut) {
        // Promise the whole file, send part of it, drop the connection (raw, so nothing is closed cleanly).
        cutAfter = null;
        final socket = await req.response.detachSocket(writeHeaders: false);
        socket.write('HTTP/1.1 ${start > 0 ? '206 Partial Content' : '200 OK'}\r\nContent-Length: ${body.length - start}\r\nConnection: close\r\n\r\n');
        socket.add(body.sublist(start, start + cut));
        await socket.flush();
        socket.destroy();
        return;
      }
      if (range != null) {
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-${body.length - 1}/${body.length}');
      }
      req.response.contentLength = body.length - start;
      req.response.add(body.sublist(start));
      await req.response.close();
    });
  }

  Future<void> stop() async => server?.close(force: true);
}

void main() {
  late Directory tmp;
  late FakeRelease host;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('grammar_dl_');
    host = FakeRelease();
  });
  tearDown(() async {
    await host.stop();
    tmp.deleteSync(recursive: true);
  });

  test('downloads, verifies and inflates a release into its own version folder', () async {
    final db = makeDb(tmp);
    await host.start(db);
    final d = ContentDownloader(source: host.url, root: Directory('${tmp.path}/content'));
    final b = await d.fetchBundle();
    final seen = <String>[];
    final dir = await d.install(b, onProgress: (p) => seen.add('${p.done}/${p.total} ${p.item}'));
    expect(dir, endsWith('9.9.9'));
    expect(File('$dir/grammar.db').readAsBytesSync(), db);
    expect(File('$dir/grammar.images').lengthSync(), 300000);
    expect(File('$dir/grammar.db.gz').existsSync(), isFalse);
    expect(Directory(dir).listSync().where((e) => e.path.endsWith('.part')), isEmpty);
    expect(seen.last, startsWith('${b.downloadBytes}/${b.downloadBytes}'));
    final opened = ContentDb.open(dir);
    expect(opened.contentVersion, '9.9.9');
    opened.close();
    // A second install has nothing to do and is quick.
    expect(await d.install(b), dir);
    d.close();
  });

  test('a cut connection resumes from the bytes already on disk', () async {
    final db = makeDb(tmp);
    await host.start(db);
    final d = ContentDownloader(source: host.url, root: Directory('${tmp.path}/content'));
    final b = await d.fetchBundle();
    host.cutAfter = 100000; // inside grammar.images (the database is small)
    await expectLater(d.install(b), throwsA(anything));
    expect(File('${tmp.path}/content/9.9.9/grammar.images.part').lengthSync(), 100000);
    final dir = await d.install(b);
    expect(host.rangeRequests, ['grammar.images bytes=100000-']);
    expect(File('$dir/grammar.images').readAsBytesSync(), host.files['grammar.images']);
    d.close();
  });

  test('a file that does not match the release is thrown away', () async {
    final db = makeDb(tmp);
    await host.start(db, corruptImages: true);
    final d = ContentDownloader(source: host.url, root: Directory('${tmp.path}/content'));
    final b = await d.fetchBundle();
    await expectLater(d.install(b), throwsA(isA<DownloadFailure>()));
    expect(File('${tmp.path}/content/9.9.9/grammar.images').existsSync(), isFalse);
    expect(File('${tmp.path}/content/9.9.9/grammar.images.part').existsSync(), isFalse);
    expect(File('${tmp.path}/content/9.9.9/grammar.db').existsSync(), isTrue, reason: 'the database came through before');
    d.close();
  });

  test('a release for a newer app is refused before anything is downloaded', () async {
    await host.start(makeDb(tmp), schema: ContentDb.supportedSchema + 1);
    final d = ContentDownloader(source: host.url, root: Directory('${tmp.path}/content'));
    await expectLater(d.fetchBundle(), throwsA(isA<UnsupportedContent>()));
    d.close();
  });

  test('removeOthers keeps the folder in use, a download under way, and files that are not its own', () async {
    final root = Directory('${tmp.path}/content')..createSync();
    for (final v in ['1.0.0', '1.1.0', '1.2.0', '1.3.0']) {
      Directory('${root.path}/$v').createSync();
      File('${root.path}/$v/grammar.db').writeAsStringSync('x');
      File('${root.path}/$v/grammar.images').writeAsStringSync('x');
    }
    File('${root.path}/1.2.0/grammar.images.part').writeAsStringSync('half'); // interrupted update
    Directory('${root.path}/1.3.0/audio').createSync(); // the user's recordings
    File('${root.path}/1.3.0/audio/1.mp3').writeAsStringSync('x');
    await ContentDownloader.removeOthers(root, '${root.path}/1.1.0');
    expect(root.listSync().map((e) => e.path.split('/').last).toList()..sort(), ['1.1.0', '1.2.0', '1.3.0']);
    expect(File('${root.path}/1.1.0/grammar.db').existsSync(), isTrue);
    expect(File('${root.path}/1.2.0/grammar.images.part').existsSync(), isTrue);
    expect(File('${root.path}/1.3.0/grammar.db').existsSync(), isFalse);
    expect(File('${root.path}/1.3.0/audio/1.mp3').existsSync(), isTrue);
    await ContentDownloader.removeOthers(root, '/somewhere/else');
    expect(root.listSync().map((e) => e.path.split('/').last).toList()..sort(), ['1.2.0', '1.3.0']);
  });

  test('versions compare numerically', () {
    expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    expect(compareVersions('1.2.0', '1.2.0'), 0);
    expect(compareVersions('1.2', '1.2.1'), lessThan(0));
    expect(compareVersions('2', '1.99.99'), greaterThan(0));
  });
}
