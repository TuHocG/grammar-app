/// `grammar-images.zip` next to grammar.db: the reading and Luyện Nói illustrations in one file,
/// so users copy one file instead of thousands. Entries are named by their content path
/// (`img/readings/x.webp`) and stored uncompressed (WebP is already compressed), so reading
/// one is a seek and a read. Deflated entries are accepted too, in case someone re-zips the
/// folder with an ordinary tool; names are matched as UTF-8 in NFC, as bundle.py writes them.
/// Zip64 is not supported (the pack is far below 4 GB).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const imagePackName = 'grammar-images.zip';

class _Entry {
  final int method, offset, size;
  const _Entry(this.method, this.offset, this.size);
}

class ImagePack {
  final String path;
  final RandomAccessFile _file;
  final Map<String, _Entry> _entries;
  ImagePack._(this.path, this._file, this._entries);

  /// Opens [path], or null when there is no such file. Throws [FormatException] when the file
  /// is there but is not a readable zip (e.g. a download that stopped half-way).
  static ImagePack? open(String path) {
    if (!File(path).existsSync()) return null;
    final f = File(path).openSync();
    try {
      return ImagePack._(path, f, _readDirectory(f));
    } catch (e) {
      f.closeSync();
      throw e is FormatException ? e : FormatException('$e');
    }
  }

  int get length => _entries.length;
  bool contains(String name) => _entries.containsKey(name);

  /// Bytes of entry [name], or null when the pack has no such entry.
  Uint8List? read(String name) {
    final e = _entries[name];
    if (e == null) return null;
    _file.setPositionSync(e.offset);
    final local = _file.readSync(30);
    if (_u32(local, 0) != 0x04034b50) throw FormatException('bad local header for $name in $path');
    _file.setPositionSync(e.offset + 30 + _u16(local, 26) + _u16(local, 28));
    final data = _file.readSync(e.size);
    if (data.length != e.size) throw FormatException('$name is cut short in $path');
    return switch (e.method) {
      0 => data,
      8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(data)),
      _ => throw FormatException('unsupported compression ${e.method} for $name in $path'),
    };
  }

  void close() => _file.closeSync();

  /// Central directory, found through the end-of-central-directory record at the file's end
  /// (after an optional comment of up to 64 KB).
  static Map<String, _Entry> _readDirectory(RandomAccessFile f) {
    final len = f.lengthSync();
    final tail = len < 22 + 0xFFFF ? len : 22 + 0xFFFF;
    f.setPositionSync(len - tail);
    final end = f.readSync(tail);
    var eocd = -1;
    for (var i = end.length - 22; i >= 0; i--) {
      if (_u32(end, i) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw const FormatException('not a zip file');
    final count = _u16(end, eocd + 10);
    final dirSize = _u32(end, eocd + 12);
    f.setPositionSync(_u32(end, eocd + 16));
    final dir = f.readSync(dirSize);
    final out = <String, _Entry>{};
    var i = 0;
    for (var n = 0; n < count; n++) {
      if (_u32(dir, i) != 0x02014b50) throw const FormatException('bad central directory');
      final nameLen = _u16(dir, i + 28);
      final name = utf8.decode(dir.sublist(i + 46, i + 46 + nameLen), allowMalformed: true);
      if (!name.endsWith('/')) out[name] = _Entry(_u16(dir, i + 10), _u32(dir, i + 42), _u32(dir, i + 20));
      i += 46 + nameLen + _u16(dir, i + 30) + _u16(dir, i + 32);
    }
    return out;
  }

  static int _u16(Uint8List b, int i) => b[i] | b[i + 1] << 8;
  static int _u32(Uint8List b, int i) => b[i] | b[i + 1] << 8 | b[i + 2] << 16 | b[i + 3] << 24;
}

/// An illustration inside an [ImagePack]. Keyed by the pack file and the entry name, like
/// [FileImage] by its path, so Flutter's image cache finds a picture decoded before.
class PackImage extends ImageProvider<PackImage> {
  final ImagePack pack;
  final String name;
  const PackImage(this.pack, this.name);

  @override
  Future<PackImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<PackImage>(this);

  @override
  ImageStreamCompleter loadImage(PackImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1.0, debugLabel: name);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = pack.read(name);
    if (bytes == null || bytes.isEmpty) throw StateError('$name is not in ${pack.path}');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is PackImage && other.pack.path == pack.path && other.name == name;

  @override
  int get hashCode => Object.hash(pack.path, name);

  @override
  String toString() => 'PackImage("${pack.path}", "$name")';
}
