/// A read-only SQLite virtual file system over a database cut into deflated blocks
/// (tool/content/host.py, docs/07 §12): the web app keeps the packs in memory as downloaded
/// (compressed) and inflates a block when SQLite reads a page of it, keeping the most recent
/// blocks inflated. Works on the native library too, which is how it is tested.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:sqlite3/common.dart';

import 'manifest.dart';

/// The blocks of one file, inflated on demand.
abstract class BlockSource {
  int get size;
  int get blockSize;

  /// Block [i], inflated. The returned bytes are not to be modified.
  Uint8List block(int i);
}

/// Inflates one raw-deflate block.
typedef Inflate = Uint8List Function(Uint8List deflated);

/// `package:archive`: the platform's zlib on the native apps, pure Dart in the browser.
Uint8List inflateBlock(Uint8List deflated) => ZLibDecoder().decodeBytes(deflated, raw: true);

/// Blocks stored deflated in packs, as the manifest describes; [cacheBytes] of inflated blocks
/// stay around (least recently used go first).
class PackedBlockSource implements BlockSource {
  final DbLayout layout;

  /// The packs, in manifest order, as downloaded.
  final List<Uint8List> packs;
  final int cacheBytes;

  /// How a deflated block is inflated (a test swaps in the browser's pure-Dart decoder).
  final Inflate inflate;
  final _cache = <int, Uint8List>{}; // insertion order = least recently used first
  int _cached = 0;
  int _misses = 0;

  /// Blocks inflated so far (for tuning).
  int get misses => _misses;

  /// Inflated bytes held at the moment.
  int get cachedBytes => _cached;

  PackedBlockSource(this.layout, this.packs, {this.cacheBytes = 16 << 20, this.inflate = inflateBlock}) {
    if (packs.length != layout.packs.length) throw ArgumentError('${packs.length} packs given, the manifest lists ${layout.packs.length}');
    for (var i = 0; i < packs.length; i++) {
      if (packs[i].length != layout.packs[i].size) throw ArgumentError('${layout.packs[i].name}: ${packs[i].length} bytes, the manifest says ${layout.packs[i].size}');
    }
  }

  @override
  int get size => layout.size;

  @override
  int get blockSize => layout.blockSize;

  @override
  Uint8List block(int i) {
    final hit = _cache.remove(i);
    if (hit != null) {
      _cache[i] = hit; // most recent again
      return hit;
    }
    _misses++;
    final where = layout.block(i);
    final pack = packs[where.pack];
    final data = inflate(Uint8List.sublistView(pack, where.offset, where.offset + where.length));
    if (data.length != layout.blockLength(i)) throw StateError('block $i inflates to ${data.length} bytes, expected ${layout.blockLength(i)}');
    _cache[i] = data;
    _cached += data.length;
    while (_cached > cacheBytes && _cache.length > 1) {
      final oldest = _cache.keys.first;
      _cached -= _cache.remove(oldest)!.length;
    }
    return data;
  }
}

/// SQLITE_IOCAP_IMMUTABLE: the file never changes, so SQLite skips locks and journal probes.
const _iocapImmutable = 0x00002000;

/// Serves one file, [fileName], from a [BlockSource]; everything else does not exist.
final class BlockVfs extends BaseVirtualFileSystem {
  final BlockSource source;
  final String fileName;
  CommonSqlite3? _registeredWith;

  BlockVfs(this.source, {this.fileName = '/grammar.db', super.name = 'grammar-blocks'});

  /// Registers this VFS with [sqlite] and opens the file through it, read-only and immutable.
  /// Close the database, then [close] this, or the registration keeps the packs alive.
  CommonDatabase open(CommonSqlite3 sqlite) {
    if (_registeredWith != null) throw StateError('$name is open already');
    sqlite.registerVirtualFileSystem(this);
    _registeredWith = sqlite;
    try {
      return sqlite.open('file:$fileName?immutable=1&vfs=$name', mode: OpenMode.readOnly, uri: true);
    } catch (_) {
      close();
      rethrow;
    }
  }

  /// Unregisters the VFS (after the database opened with [open] is closed).
  void close() {
    _registeredWith?.unregisterVirtualFileSystem(this);
    _registeredWith = null;
  }

  /// The file exists and can be read; it cannot be written (SQLITE_ACCESS_READWRITE = 1).
  @override
  int xAccess(String path, int flags) => path == fileName && flags != 1 ? 1 : 0;

  @override
  void xDelete(String path, int syncDir) => throw const VfsException(SqlError.SQLITE_READONLY);

  @override
  String xFullPathName(String path) => path;

  @override
  XOpenResult xOpen(Sqlite3Filename path, int flags) {
    if (path.path != fileName || flags & SqlFlag.SQLITE_OPEN_MAIN_DB == 0) throw const VfsException(SqlError.SQLITE_CANTOPEN);
    return (outFlags: SqlFlag.SQLITE_OPEN_READONLY, file: _BlockFile(source));
  }

  @override
  void xSleep(Duration duration) {}
}

class _BlockFile extends BaseVfsFile {
  final BlockSource source;
  _BlockFile(this.source);

  @override
  int readInto(Uint8List buffer, int offset) {
    final size = source.size;
    if (offset >= size) return 0;
    final end = offset + buffer.length < size ? offset + buffer.length : size;
    var pos = offset;
    while (pos < end) {
      final i = pos ~/ source.blockSize;
      final block = source.block(i);
      final inBlock = pos - i * source.blockSize;
      final n = (end - pos) < (block.length - inBlock) ? end - pos : block.length - inBlock;
      buffer.setRange(pos - offset, pos - offset + n, block, inBlock);
      pos += n;
    }
    return end - offset;
  }

  @override
  int get xDeviceCharacteristics => _iocapImmutable;

  @override
  int xCheckReservedLock() => 0;

  @override
  void xClose() {}

  @override
  int xFileSize() => source.size;

  @override
  void xLock(int mode) {}

  @override
  void xUnlock(int mode) {}

  @override
  void xSync(int flags) {}

  @override
  void xTruncate(int size) => throw const VfsException(SqlError.SQLITE_READONLY);

  @override
  void xWrite(Uint8List buffer, int fileOffset) => throw const VfsException(SqlError.SQLITE_READONLY);
}
