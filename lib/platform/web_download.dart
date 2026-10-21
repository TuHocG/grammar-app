/// Downloading the web host's data into the browser (docs/07 §12, docs/09 §4): the manifests,
/// the database packs, and the pictures, each kept in Cache Storage under its URL.
///
/// Two pointers: what the host says is current (`data/latest.json`, fetched afresh when online)
/// and what is *installed* — the version whose packs are all in the cache. Only the installed
/// one is opened; a newer one is offered, and becomes installed once its packs are complete, so
/// going offline half-way through an update never takes the working data away.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../data/download_progress.dart';
import '../data/manifest.dart';
import 'web_store.dart';

/// Where the host's files are: the app's own origin and folder, or, while developing with
/// `flutter run -d chrome`, the server of `tool/web/serve.py` named by
/// `--dart-define=GRAMMAR_HOST_URL=http://localhost:8080/` (README "Bản web").
class HostLocation {
  static const _override = String.fromEnvironment('GRAMMAR_HOST_URL');

  final Uri base;
  const HostLocation(this.base);
  factory HostLocation.ofApp() => HostLocation(_override.isEmpty ? Uri.base.removeFragment() : Uri.parse(_override));

  String url(String rel) => base.resolve(rel).toString();
  String get latestUrl => url('data/latest.json');

  /// Not a real file: the cache key of the installed pointer.
  String get installedUrl => url('data/installed.json');

  /// A picture, with its hash in the query so the browser cache never serves a stale one.
  String imageUrl(String rel, ImageEntry? e) => e == null ? url(rel) : '${url(rel)}?v=${e.sha8}';
}

/// The host could not be read (offline, or not answering).
class HostUnreachable implements Exception {
  final Object cause;
  const HostUnreachable(this.cause);
  @override
  String toString() => 'không đọc được máy chủ: $cause';
}

/// A download that did not match the manifest, or could not finish.
class DownloadFailure implements Exception {
  final String message;
  const DownloadFailure(this.message);
  @override
  String toString() => message;
}

typedef HostContent = (HostLatest, HostManifest);

/// The current version on the host and its manifest, fetched afresh. The manifest is remembered
/// under its URL for later offline starts. Throws [HostUnreachable], or [FormatException] when
/// the host's files are not understood (a newer format: update the app).
Future<HostContent> fetchLatest(HostLocation host) async {
  final String latestText;
  final String manifestText;
  final HostLatest latest;
  try {
    latestText = await fetchJsonText(host.latestUrl);
    latest = HostLatest.parse(latestText);
    manifestText = await fetchJsonText(host.url(latest.manifest));
  } on FormatException {
    rethrow;
  } catch (e) {
    throw HostUnreachable(e);
  }
  final manifest = HostManifest.parse(manifestText);
  await putText(metaCache, host.url(latest.manifest), manifestText);
  return (latest, manifest);
}

/// The installed version, or null before the first download.
Future<HostContent?> loadInstalled(HostLocation host) async {
  final text = await cachedText(metaCache, host.installedUrl);
  if (text == null) return null;
  final latest = HostLatest.parse(text);
  final manifestText = await cachedText(metaCache, host.url(latest.manifest));
  if (manifestText == null) return null;
  return (latest, HostManifest.parse(manifestText));
}

/// Records [latest] as installed: call once every pack of its manifest is in the cache.
Future<void> markInstalled(HostLocation host, HostLatest latest) =>
    putText(metaCache, host.installedUrl, jsonEncode({'version': latest.version, 'schema': latest.schema, 'manifest': latest.manifest}));

/// The packs of [m] that are in the cache, in manifest order; null when one is missing.
Future<List<Uint8List>?> cachedPacks(HostManifest m, HostLocation host) async {
  final out = <Uint8List>[];
  for (final p in m.db.packs) {
    final bytes = await cachedBytes(packsCache, host.url(p.name));
    if (bytes == null || bytes.length != p.size) return null;
    out.add(bytes);
  }
  return out;
}

/// Bytes still to download for the database of [m].
Future<int> missingPackBytes(HostManifest m, HostLocation host) async {
  var n = 0;
  for (final p in m.db.packs) {
    if (!await isCached(packsCache, host.url(p.name))) n += p.size;
  }
  return n;
}

/// Downloads the packs of [m] that are not cached yet, verifying each against the manifest,
/// then marks [latest] installed. Resumes per pack: a pack already in the cache is not fetched
/// again. Throws [DownloadFailure] (with a message for the user).
Future<void> installContent(HostLatest latest, HostManifest m, HostLocation host, {void Function(DownloadProgress)? onProgress}) async {
  final total = m.db.packs.fold(0, (a, p) => a + p.size);
  var done = 0;
  for (final p in m.db.packs) {
    final url = host.url(p.name);
    if (!await isCached(packsCache, url)) {
      final Uint8List bytes;
      try {
        bytes = await fetchBytes(url, onProgress: (got, _) => onProgress?.call(DownloadProgress(done + got, total, p.name)), requireType: 'application/octet-stream');
      } catch (e) {
        throw DownloadFailure(onLine ? 'Không tải được ${p.name}: $e' : 'Mất kết nối mạng. Phần đã tải được giữ lại.');
      }
      if (bytes.length != p.size || sha256.convert(bytes).toString() != p.sha256) throw DownloadFailure('${p.name} tải về không khớp với máy chủ; hãy thử lại.');
      try {
        await putBytes(packsCache, url, bytes);
      } catch (e) {
        throw DownloadFailure('Trình duyệt không cho lưu (hết chỗ?): $e');
      }
    }
    done += p.size;
    onProgress?.call(DownloadProgress(done, total, p.name));
  }
  await markInstalled(host, latest);
  // Only now are the packs of the version installed before unused. (Never at start-up: the
  // packs of an update cut off half-way must survive, so that it resumes.)
  final wanted = {for (final p in m.db.packs) host.url(p.name)};
  for (final url in await cachedUrls(packsCache)) {
    if (!wanted.contains(url)) await deleteCachedUrl(packsCache, url);
  }
}

/// Fetches the pictures [rels] of [m] that are not cached yet (for offline use). A picture that
/// cannot be fetched is skipped; the run stops when the network goes away.
Future<void> prefetchImages(HostManifest m, HostLocation host, Iterable<String> rels, {void Function(DownloadProgress)? onProgress}) async {
  final list = rels.where(m.images.containsKey).toList();
  final total = list.fold(0, (a, r) => a + m.images[r]!.size);
  var done = 0;
  for (final rel in list) {
    if (!onLine) return;
    final url = host.imageUrl(rel, m.images[rel]);
    if (!await isCached(imagesCache, url)) {
      try {
        await putBytes(imagesCache, url, await fetchBytes(url, requireType: 'image/'), contentType: 'image/webp');
      } catch (_) {
        // Missing on the host, or no room: the lesson shows its fallback instead.
      }
    }
    done += m.images[rel]!.size;
    onProgress?.call(DownloadProgress(done, total, rel));
  }
}

/// The Từ Vựng Tranh pages: hotspots are drawn on them, so the lessons need them offline.
Iterable<String> picturePages(HostManifest m) => m.images.keys.where((k) => k.startsWith('img/pages/'));
