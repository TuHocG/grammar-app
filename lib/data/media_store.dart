/// Where the pictures and recordings of the content come from, apart from what grammar.db
/// embeds: a folder next to grammar.db on the desktop and mobile apps (`folder_media.dart`), the
/// web host on the web (docs/07 §12). [ContentDb.imageProvider] asks the store for every picture
/// that is not in the database; the pages that read aloud ask `audioFor` (app/providers.dart) for
/// the recording.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// `user_setting` keys of the folders the user picked instead of the defaults (Cài Đặt → Dữ liệu).
const audioDirKey = 'audio_dir';
const videoDirKey = 'video_dir';

/// A recording the player can open: a file on this device, or a URL.
sealed class AudioRef {
  const AudioRef();
}

class AudioFile extends AudioRef {
  final String path;
  const AudioFile(this.path);
  @override
  String toString() => path;
}

/// A recording streamed from the audio host: not on this device.
class AudioUrl extends AudioRef {
  final String url;
  const AudioUrl(this.url);
  @override
  String toString() => url;
}

/// A recording the web app downloaded into Cache Storage; [open] makes a URL the player can
/// load (a blob URL), done when the recording is first played.
class AudioCached extends AudioRef {
  final String key;
  final Future<String> Function() open;
  const AudioCached(this.key, this.open);
  @override
  String toString() => key;
}

abstract class MediaStore {
  /// The picture of a relative content path (`img/readings/x.webp`, `img/pages/1.webp`).
  ImageProvider image(String rel);

  /// The recording of a relative content path (`audio/12.mp3`) kept on this device, or null when
  /// it is not there: the caller then streams it from the audio host. [dir] is the folder the
  /// user picked instead of the default one, when any.
  AudioRef? audio(String rel, {String? dir});

  /// Releases what the store holds open (the illustrations zip).
  void close();
}

/// A store with nothing in it (the web app before its data layer, docs/07 §12).
class NoMedia implements MediaStore {
  const NoMedia();

  @override
  ImageProvider image(String rel) => const _NoImage();

  @override
  AudioRef? audio(String rel, {String? dir}) => null;

  @override
  void close() {}
}

/// An image that never resolves, so `Image(errorBuilder:)` shows its fallback.
class _NoImage extends ImageProvider<_NoImage> {
  const _NoImage();
  @override
  Future<_NoImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<_NoImage>(this);
  @override
  ImageStreamCompleter loadImage(_NoImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Future<ImageInfo>.error(StateError('no media store')));
}
