/// Downloading the real-voice recordings (Các Bài Âm Thanh Thực) from [grammarAudioUrl] for use
/// without a network: into the recordings folder on the desktop and mobile apps
/// (`recordings_io.dart`), into Cache Storage on the web (`recordings_web.dart`). A reading whose
/// recording is not downloaded streams it instead (`audioFor`, app/providers.dart).
library;

import '../data/content_db.dart';
import '../data/user_db.dart';
import 'recordings_io.dart' if (dart.library.js_interop) 'recordings_web.dart' as impl;

/// A recording that could not be downloaded (HTTP error, connection cut, not audio).
class RecordingFailure implements Exception {
  final String message;
  const RecordingFailure(this.message);
  @override
  String toString() => message;
}

/// [RecordingDownloader.stop] was called.
class RecordingsStopped implements Exception {
  const RecordingsStopped();
  @override
  String toString() => 'Đã dừng tải.';
}

/// Progress of [RecordingDownloader.fetchAll]: whole files done, and the share of the work done
/// counting the file under way.
class RecordingsProgress {
  final int done;
  final int total;
  final double fraction;
  const RecordingsProgress(this.done, this.total, this.fraction);
}

/// The recordings of the content (`audio/1.mp3` …), in reading order.
List<String> allRecordings(ContentDb db) => [for (final r in db.raw.select('SELECT audio FROM reading WHERE audio IS NOT NULL ORDER BY id')) r['audio'] as String];

class RecordingDownloader {
  final impl.RecordingFetcher _fetcher;
  bool _stopped = false;
  RecordingDownloader(ContentDb db, UserDb user) : _fetcher = impl.RecordingFetcher(db, user);

  /// Downloads [rels] one after another; a recording already here is skipped. Throws
  /// [RecordingFailure] or [RecordingsStopped]; the files that arrived whole stay.
  Future<void> fetchAll(List<String> rels, {void Function(RecordingsProgress)? onProgress}) async {
    for (var i = 0; i < rels.length; i++) {
      if (_stopped) throw const RecordingsStopped();
      onProgress?.call(RecordingsProgress(i, rels.length, i / rels.length));
      await _fetcher.fetch(rels[i], (got, total) {
        if (_stopped) throw const RecordingsStopped();
        final part = total == null || total <= 0 ? 0.0 : (got / total).clamp(0.0, 1.0);
        onProgress?.call(RecordingsProgress(i, rels.length, (i + part) / rels.length));
      });
    }
    onProgress?.call(RecordingsProgress(rels.length, rels.length, 1));
  }

  /// Stops the download in progress; what arrived stays for a later resume.
  void stop() {
    _stopped = true;
    _fetcher.cancel();
  }

  void close() => _fetcher.close();
}
