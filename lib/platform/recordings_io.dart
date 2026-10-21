/// The recordings of the desktop and mobile apps: files `1.mp3` … in the recordings folder (Cài
/// Đặt → Dữ liệu → Âm thanh thực, `audio/` beside the data by default). Each is written to a
/// `.part` that resumes with a Range request and is renamed once whole. The audio host publishes
/// no checksums: a file is whole when it has the length the server announced.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../app/config.dart';
import '../data/content_db.dart';
import '../data/media_locations.dart';
import '../data/user_db.dart';
import 'recordings.dart';

class RecordingFetcher {
  /// The recordings folder.
  final String dir;

  /// The audio host (a URL ending with `/`), [grammarAudioUrl] but in tests.
  final String host;
  HttpClient _http = _client();
  int _generation = 0;
  RecordingFetcher(ContentDb db, UserDb user) : this.into(audioDir(db, user));
  RecordingFetcher.into(this.dir, {this.host = grammarAudioUrl});

  static HttpClient _client() => HttpClient()
    ..userAgent = 'Grammar4'
    ..autoUncompress =
        false // a Range resumes the file as stored, so it must arrive as stored
    ..connectionTimeout = const Duration(seconds: 15);

  /// Downloads under way, by target file, across fetchers (a reading page and Cài Đặt may both
  /// fetch a recording): a second fetch waits for the first instead of appending to its `.part`.
  static final _running = <String, Future<void>>{};

  /// Downloads the recording of [rel] (`audio/12.mp3`) into [dir], unless it is there already.
  /// [onBytes] gets the bytes of the file so far and its length when known; it may throw to stop.
  Future<void> fetch(String rel, void Function(int got, int? total) onBytes) async {
    final target = File(p.join(dir, p.basename(rel)));
    final key = p.canonicalize(target.path);
    final other = _running[key];
    if (other != null) {
      try {
        await other;
        return;
      } on RecordingsStopped {
        // the other fetch was stopped, not this one: carry on with the download
      }
      return fetch(rel, onBytes);
    }
    final run = _running[key] = _fetch(target, onBytes);
    try {
      await run;
    } finally {
      if (identical(_running[key], run)) _running.remove(key);
    }
  }

  Future<void> _fetch(File target, void Function(int got, int? total) onBytes) async {
    final gen = _generation;
    final name = p.basename(target.path);
    if (await target.exists()) return;
    await Directory(dir).create(recursive: true);
    final part = File('${target.path}.part');
    var have = await part.exists() ? await part.length() : 0;
    final HttpClientResponse res;
    try {
      final req = await _http.getUrl(Uri.parse('$host$name'));
      req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      res = await req.close();
    } catch (e) {
      if (gen != _generation) throw const RecordingsStopped();
      throw RecordingFailure(e is SocketException ? 'Không kết nối được máy chủ âm thanh (không có mạng?).' : '$name: $e');
    }
    if (res.statusCode == HttpStatus.requestedRangeNotSatisfiable && have > 0) {
      // What is in the .part is not a prefix of the file on the host (it changed): start over.
      await res.drain<void>();
      await part.delete();
      return _fetch(target, onBytes);
    }
    final resumed = res.statusCode == HttpStatus.partialContent;
    if (res.statusCode != HttpStatus.ok && !resumed) {
      await res.drain<void>();
      throw RecordingFailure('$name: máy chủ âm thanh trả lỗi HTTP ${res.statusCode}.');
    }
    final type = res.headers.contentType?.mimeType ?? '';
    if (!type.startsWith('audio/')) {
      await res.drain<void>();
      throw RecordingFailure('$name: máy chủ không trả về âm thanh mà là "$type".');
    }
    if (!resumed) have = 0; // the server sent the whole file: start over
    final total = res.contentLength < 0 ? null : have + res.contentLength;
    final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in res.timeout(const Duration(seconds: 30))) {
        if (gen != _generation) throw const RecordingsStopped();
        sink.add(chunk);
        have += chunk.length;
        onBytes(have, total);
      }
    } on RecordingsStopped {
      rethrow;
    } catch (e) {
      if (gen != _generation) throw const RecordingsStopped();
      throw RecordingFailure('$name: kết nối bị ngắt sau ${have ~/ 1024} KB; tải lại để tải nốt.');
    } finally {
      await sink.close();
    }
    // A connection that closed early may end the stream like a complete one: keep what arrived.
    if (total != null && have < total) throw RecordingFailure('$name: kết nối bị ngắt sau ${have ~/ 1024} KB; tải lại để tải nốt.');
    await part.rename(target.path);
  }

  /// Stops the download in progress at once.
  void cancel() {
    _generation++;
    _http.close(force: true);
    _http = _client();
  }

  void close() => _http.close(force: true);
}
