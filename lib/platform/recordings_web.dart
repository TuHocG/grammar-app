/// The recordings of the web app: kept in Cache Storage under their URL on the audio host, and
/// listed in [WebMediaStore] so a reading plays the copy instead of the stream.
library;

import 'dart:typed_data';

import '../app/config.dart';
import '../data/content_db.dart';
import '../data/user_db.dart';
import '../data/web_media.dart';
import 'recordings.dart';
import 'web_store.dart';

class RecordingFetcher {
  final WebMediaStore? _store;
  bool _cancelled = false;
  RecordingFetcher(ContentDb db, UserDb user) : _store = db.media is WebMediaStore ? db.media as WebMediaStore : null;

  /// Downloads the recording of [rel] into Cache Storage, unless it is there already. [onBytes]
  /// may throw to stop: the fetch is abandoned at the next chunk.
  Future<void> fetch(String rel, void Function(int got, int? total) onBytes) async {
    final url = recordingUrl(rel);
    if (!await isCached(audioCache, url)) {
      if (!onLine) throw const RecordingFailure('Không có mạng.');
      final name = rel.split('/').last;
      final Uint8List bytes;
      try {
        bytes = await fetchBytes(
          url,
          requireType: 'audio/',
          onProgress: (got, total) {
            if (_cancelled) throw const RecordingsStopped();
            onBytes(got, total);
          },
        );
      } on RecordingsStopped {
        rethrow;
      } catch (e) {
        throw RecordingFailure('$name: $e');
      }
      if (_cancelled) throw const RecordingsStopped();
      try {
        await putBytes(audioCache, url, bytes, contentType: 'audio/mpeg');
      } catch (_) {
        throw RecordingFailure('$name: trình duyệt không còn chỗ lưu.');
      }
    }
    _store?.recordingCached(url);
  }

  void cancel() => _cancelled = true;

  void close() {}
}
