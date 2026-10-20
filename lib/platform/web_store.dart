/// The browser's storage and network, for the web app only (docs/07 §12): Cache Storage holds
/// the downloaded packs and pictures, keyed by their URL; `fetch` streams downloads with
/// progress; the storage manager says whether the data may be evicted; a Web Lock keeps a
/// second tab from writing user.db.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Cache Storage names. Packs and pictures are content-addressed (hash in the URL), so an entry
/// never goes stale; the manifests are small and refreshed on every online start.
const packsCache = 'grammar-packs';
const imagesCache = 'grammar-images';
const metaCache = 'grammar-meta';

/// A request that did not succeed: a status other than 2xx, or not the kind of content expected.
class FetchFailure implements Exception {
  final String url;
  final String reason;
  const FetchFailure(this.url, this.reason);
  @override
  String toString() => '$reason ($url)';
}

Future<web.Cache> _open(String cacheName) => web.window.caches.open(cacheName).toDart;

/// The bytes stored under [url] in [cacheName], or null.
Future<Uint8List?> cachedBytes(String cacheName, String url) async {
  final r = await (await _open(cacheName)).match(url.toJS).toDart;
  if (r == null) return null;
  return (await r.arrayBuffer().toDart).toDart.asUint8List();
}

Future<bool> isCached(String cacheName, String url) async => await (await _open(cacheName)).match(url.toJS).toDart != null;

Future<void> putBytes(String cacheName, String url, Uint8List bytes, {String contentType = 'application/octet-stream'}) async {
  final headers = web.Headers()..set('content-type', contentType);
  await (await _open(cacheName)).put(url.toJS, web.Response(bytes.toJS, web.ResponseInit(headers: headers))).toDart;
}

Future<String?> cachedText(String cacheName, String url) async {
  final r = await (await _open(cacheName)).match(url.toJS).toDart;
  return r == null ? null : (await r.text().toDart).toDart;
}

Future<void> putText(String cacheName, String url, String text) async {
  final headers = web.Headers()..set('content-type', 'application/json');
  await (await _open(cacheName)).put(url.toJS, web.Response(text.toJS, web.ResponseInit(headers: headers))).toDart;
}

/// The URLs stored in [cacheName].
Future<List<String>> cachedUrls(String cacheName) async => [for (final r in (await (await _open(cacheName)).keys().toDart).toDart) r.url];

Future<void> deleteCache(String cacheName) async {
  await web.window.caches.delete(cacheName).toDart;
}

Future<void> deleteCachedUrl(String cacheName, String url) async {
  await (await _open(cacheName)).delete(url.toJS).toDart;
}

/// Downloads [url] (bypassing the HTTP cache: Cache Storage is the copy that counts), reporting
/// bytes received and the total when the server says it. [requireType]: the content type must
/// start with it (a host that answers missing paths with its index page is caught here).
Future<Uint8List> fetchBytes(String url, {void Function(int received, int? total)? onProgress, String? requireType}) async {
  final r = await web.window.fetch(url.toJS, web.RequestInit(cache: 'no-store')).toDart;
  if (!r.ok) throw FetchFailure(url, 'HTTP ${r.status}');
  final type = r.headers.get('content-type') ?? '';
  if (requireType != null && !type.startsWith(requireType)) throw FetchFailure(url, 'không phải $requireType mà là $type');
  final length = r.headers.get('content-length');
  final total = length == null ? null : int.tryParse(length);
  final body = r.body;
  if (onProgress == null || body == null) return (await r.arrayBuffer().toDart).toDart.asUint8List();
  final reader = body.getReader() as web.ReadableStreamDefaultReader;
  final out = BytesBuilder(copy: false);
  while (true) {
    final chunk = await reader.read().toDart;
    if (chunk.done) break;
    out.add((chunk.value as JSUint8Array).toDart);
    onProgress(out.length, total);
  }
  return out.takeBytes();
}

/// Fetches a small JSON file afresh (latest.json, the manifests).
Future<String> fetchJsonText(String url) async {
  final r = await web.window.fetch(url.toJS, web.RequestInit(cache: 'no-cache')).toDart;
  if (!r.ok) throw FetchFailure(url, 'HTTP ${r.status}');
  final type = r.headers.get('content-type') ?? '';
  if (!type.contains('json')) throw FetchFailure(url, 'không phải JSON mà là $type');
  return (await r.text().toDart).toDart;
}

bool get onLine => web.window.navigator.onLine;

/// Asks the browser never to evict this origin's storage; true when granted (or already so).
Future<bool> persistStorage() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> storagePersisted() async {
  try {
    return (await web.window.navigator.storage.persisted().toDart).toDart;
  } catch (_) {
    return false;
  }
}

/// Bytes used and available for this origin, when the browser tells.
Future<({int usage, int quota})?> storageEstimate() async {
  try {
    final e = await web.window.navigator.storage.estimate().toDart;
    return (usage: e.usage, quota: e.quota);
  } catch (_) {
    return null;
  }
}

/// Opened from the home screen (or installed), not in a browser tab.
bool get isStandalone {
  if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  final s = web.window.navigator.getProperty<JSAny?>('standalone'.toJS); // iOS Safari only
  return s != null && s.isA<JSBoolean>() && (s as JSBoolean).toDart;
}

/// iPhone or iPad (iPadOS reports itself as a Mac with touch).
bool get isIosDevice {
  final n = web.window.navigator;
  final ua = n.userAgent;
  return ua.contains('iPhone') || ua.contains('iPad') || (ua.contains('Macintosh') && n.maxTouchPoints > 1);
}

/// Safari itself on iOS, as opposed to another browser or the web view inside an app (Zalo,
/// Facebook, Messenger…), which cannot add to the home screen and may keep nothing.
bool get isIosSafari {
  final ua = web.window.navigator.userAgent;
  return isIosDevice && ua.contains('Safari') && !ua.contains('CriOS') && !ua.contains('FxiOS') && !ua.contains('FBAN') && !ua.contains('FBAV') && !ua.contains('Zalo');
}

/// Holds [name] for the life of this page; false when another tab holds it already.
Future<bool> acquireSessionLock(String name) async {
  final granted = Completer<bool>();
  final hold = Completer<JSAny?>(); // never completes: the lock is released when the page goes
  try {
    unawaited(
      web.window.navigator.locks
          .request(
            name,
            web.LockOptions(ifAvailable: true),
            ((web.Lock? lock) {
              granted.complete(lock != null);
              return lock == null ? null : hold.future.toJS;
            }).toJS,
          )
          .toDart
          .catchError((Object _) {
            if (!granted.isCompleted) granted.complete(true); // the request failed (sandboxed page?): carry on
            return null;
          }),
    );
    return await granted.future;
  } catch (_) {
    return true; // no Web Locks (old browser): carry on
  }
}

/// Runs [f] when the page is hidden or about to go away (the time to flush user.db).
void onPageHide(void Function() f) {
  web.document.addEventListener(
    'visibilitychange',
    (web.Event _) {
      if (web.document.visibilityState == 'hidden') f();
    }.toJS,
  );
  web.window.addEventListener('pagehide', ((web.Event _) => f()).toJS);
}

/// Reloads the page (after the offline data was deleted, or to pick up a new build).
void reloadPage() => web.window.location.reload();
