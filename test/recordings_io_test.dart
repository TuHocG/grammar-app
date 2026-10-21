// Downloading the real-voice recordings on the desktop and mobile apps
// (lib/platform/recordings_io.dart) against a local server: a whole file, a connection cut
// half-way that resumes with a Range request, a missing file, and a host that answers with a page.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/platform/recordings.dart';
import 'package:grammar/platform/recordings_io.dart';

class FakeAudioHost {
  final Map<String, Uint8List> files = {};
  HttpServer? server;

  /// Close the connection after this many bytes of a file, once (null: never).
  int? cutAfter;
  final rangeRequests = <String>[];
  var requests = 0;

  /// Answer with an HTML page instead of the file.
  bool html = false;

  String get url => 'http://127.0.0.1:${server!.port}/';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((req) async {
      requests++;
      final name = req.uri.pathSegments.last;
      final body = files[name];
      if (body == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      if (html) {
        req.response.headers.contentType = ContentType.html;
        req.response.write('<html></html>');
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
      if (cut != null && body.length - start > cut) {
        // Promise the whole file, send part of it, drop the connection.
        cutAfter = null;
        final socket = await req.response.detachSocket(writeHeaders: false);
        socket.write('HTTP/1.1 200 OK\r\ncontent-type: audio/mpeg\r\ncontent-length: ${body.length}\r\n\r\n');
        socket.add(body.sublist(0, cut));
        await socket.flush();
        socket.destroy();
        return;
      }
      req.response.headers.contentType = ContentType('audio', 'mpeg');
      if (start > 0) {
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
  late FakeAudioHost host;
  final mp3 = Uint8List.fromList(List.generate(200000, (i) => i % 241));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('recordings_');
    host = FakeAudioHost()..files['7.mp3'] = mp3;
    await host.start();
  });

  tearDown(() async {
    await host.stop();
    await tmp.delete(recursive: true);
  });

  RecordingFetcher fetcher() => RecordingFetcher.into('${tmp.path}/audio', host: host.url);

  test('downloads a recording into the folder, then skips it', () async {
    final f = fetcher();
    var last = 0;
    await f.fetch('audio/7.mp3', (got, total) {
      expect(total, mp3.length);
      last = got;
    });
    expect(last, mp3.length);
    expect(File('${tmp.path}/audio/7.mp3').readAsBytesSync(), mp3);
    expect(File('${tmp.path}/audio/7.mp3.part').existsSync(), isFalse);
    var called = false;
    await f.fetch('audio/7.mp3', (_, _) => called = true);
    expect(called, isFalse);
    f.close();
  });

  test('a connection cut half-way keeps the part, and the next try resumes it', () async {
    host.cutAfter = 50000;
    final f = fetcher();
    await expectLater(f.fetch('audio/7.mp3', (_, _) {}), throwsA(isA<RecordingFailure>()));
    expect(File('${tmp.path}/audio/7.mp3').existsSync(), isFalse);
    expect(File('${tmp.path}/audio/7.mp3.part').lengthSync(), 50000);
    await f.fetch('audio/7.mp3', (_, _) {});
    expect(host.rangeRequests, ['7.mp3 bytes=50000-']);
    expect(File('${tmp.path}/audio/7.mp3').readAsBytesSync(), mp3);
    f.close();
  });

  test('a missing file or a page instead of audio is a failure, and nothing is kept', () async {
    final f = fetcher();
    await expectLater(f.fetch('audio/8.mp3', (_, _) {}), throwsA(isA<RecordingFailure>().having((e) => e.message, 'message', contains('HTTP 404'))));
    host.html = true;
    await expectLater(f.fetch('audio/7.mp3', (_, _) {}), throwsA(isA<RecordingFailure>().having((e) => e.message, 'message', contains('text/html'))));
    expect(Directory('${tmp.path}/audio').listSync(), isEmpty);
    f.close();
  });

  test('two fetchers of the same recording download it once, whole', () async {
    final a = fetcher(), b = fetcher();
    await Future.wait([a.fetch('audio/7.mp3', (_, _) {}), b.fetch('audio/7.mp3', (_, _) {})]);
    expect(host.requests, 1);
    expect(File('${tmp.path}/audio/7.mp3').readAsBytesSync(), mp3);
    a.close();
    b.close();
  });

  test('stopping from the progress callback ends the download with RecordingsStopped', () async {
    final f = fetcher();
    await expectLater(f.fetch('audio/7.mp3', (_, _) => throw const RecordingsStopped()), throwsA(isA<RecordingsStopped>()));
    expect(File('${tmp.path}/audio/7.mp3').existsSync(), isFalse);
    f.close();
  });
}
