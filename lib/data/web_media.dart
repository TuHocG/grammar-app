/// The [MediaStore] of the web app: pictures come from the host, each kept in Cache Storage
/// after its first use so it is there offline; there are no recordings (docs/07 §12).
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../platform/web_download.dart';
import '../platform/web_store.dart';
import 'manifest.dart';
import 'media_store.dart';

class WebMediaStore implements MediaStore {
  final HostLocation host;
  final HostManifest manifest;
  WebMediaStore(this.host, this.manifest);

  /// Only pictures the manifest lists: anything else is not on the host.
  @override
  ImageProvider image(String rel) {
    final e = manifest.images[rel];
    return e == null ? const NoMedia().image(rel) : CachedUrlImage(host.imageUrl(rel, e));
  }

  @override
  AudioRef? audio(String rel, {String? dir}) => null;

  @override
  void close() {}
}

/// A picture by URL: Cache Storage first, else fetched and stored. Keyed by the URL, like
/// [NetworkImage], so Flutter's image cache finds a picture decoded before.
class CachedUrlImage extends ImageProvider<CachedUrlImage> {
  final String url;
  const CachedUrlImage(this.url);

  @override
  Future<CachedUrlImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<CachedUrlImage>(this);

  @override
  ImageStreamCompleter loadImage(CachedUrlImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1.0, debugLabel: url);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    var bytes = await cachedBytes(imagesCache, url);
    if (bytes == null) {
      bytes = await fetchBytes(url, requireType: 'image/');
      final copy = bytes;
      unawaited(putBytes(imagesCache, url, copy, contentType: 'image/webp').catchError((_) {})); // no room: shown anyway
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is CachedUrlImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedUrlImage("$url")';
}
