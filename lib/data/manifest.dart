/// What the web host serves (tool/content/host.py, docs/07 §12): `data/latest.json` names the
/// current content version and its manifest; the manifest says how grammar.db is cut into
/// compressed blocks and packs, and lists the pictures.
library;

import 'dart:convert';

/// `data/latest.json`.
class HostLatest {
  final String version;
  final int schema;

  /// Path of the manifest, relative to the host root (`data/1.2.0/manifest.json`).
  final String manifest;
  const HostLatest({required this.version, required this.schema, required this.manifest});

  factory HostLatest.fromJson(Map<String, dynamic> j) => HostLatest(version: j['version'] as String, schema: j['schema'] as int, manifest: j['manifest'] as String);

  /// Throws [FormatException] on anything that is not a latest.json.
  static HostLatest parse(String text) => _parse(text, 'latest.json', HostLatest.fromJson);
}

/// Decodes [text] and builds the object, turning every failure into a [FormatException].
T _parse<T>(String text, String what, T Function(Map<String, dynamic>) build) {
  final j = jsonDecode(text);
  if (j is! Map<String, dynamic>) throw FormatException('$what: not a JSON object');
  try {
    return build(j);
  } on TypeError catch (e) {
    throw FormatException('$what: $e');
  }
}

/// `data/<version>/manifest.json`.
class HostManifest {
  /// Highest manifest `format` this app reads.
  static const supportedFormat = 1;

  final int format;
  final String contentVersion;
  final int schema;
  final String date;
  final String variant;
  final DbLayout db;

  /// Content path → (bytes, first 8 hex digits of the sha256), for every picture on the host.
  final Map<String, ImageEntry> images;

  const HostManifest({required this.format, required this.contentVersion, required this.schema, required this.date, required this.variant, required this.db, required this.images});

  factory HostManifest.fromJson(Map<String, dynamic> j) => HostManifest(
    format: j['format'] as int,
    contentVersion: j['content_version'] as String,
    schema: j['schema'] as int,
    date: (j['date'] ?? '') as String,
    variant: (j['variant'] ?? 'web') as String,
    db: DbLayout.fromJson(j['db'] as Map<String, dynamic>),
    images: {for (final e in (j['images'] as Map<String, dynamic>).entries) e.key: ImageEntry(size: (e.value as List)[0] as int, sha8: (e.value as List)[1] as String)},
  );

  /// Throws [FormatException] on a manifest this app does not understand: a newer `format` is
  /// reported as such before anything else is read, so the app can say "update the app".
  static HostManifest parse(String text) => _parse(text, 'manifest', (j) {
    final format = j['format'];
    if (format is! int) throw const FormatException('manifest: no format');
    if (format > supportedFormat) throw FormatException('manifest format $format, this app reads up to $supportedFormat');
    return HostManifest.fromJson(j);
  });
}

class ImageEntry {
  final int size;
  final String sha8;
  const ImageEntry({required this.size, required this.sha8});
}

/// Where each block of the database lives: block `i` covers bytes `[i * blockSize, (i + 1) *
/// blockSize)` of the file (the last one shorter) and is stored deflated in one of the packs.
class DbLayout {
  final int size;
  final String sha256;
  final int pageSize;
  final int blockSize;
  final List<PackInfo> packs;

  /// Pack index of every block, in block order.
  final List<int> _packOf;

  /// Offset of every block inside its pack.
  final List<int> _offsetOf;

  /// Compressed length of every block.
  final List<int> _lengthOf;

  DbLayout({required this.size, required this.sha256, required this.pageSize, required this.blockSize, required this.packs}) : _packOf = [], _offsetOf = [], _lengthOf = [] {
    if (blockSize <= 0 || pageSize <= 0 || blockSize % pageSize != 0) throw FormatException('block size $blockSize is not a multiple of the page size $pageSize');
    for (var p = 0; p < packs.length; p++) {
      var off = 0;
      for (final n in packs[p].blocks) {
        _packOf.add(p);
        _offsetOf.add(off);
        _lengthOf.add(n);
        off += n;
      }
      if (off != packs[p].size) throw FormatException('${packs[p].name}: blocks add up to $off bytes, pack is ${packs[p].size}');
    }
    if (_packOf.length != blockCount) throw FormatException('${_packOf.length} blocks listed, $blockCount needed for $size bytes');
  }

  factory DbLayout.fromJson(Map<String, dynamic> j) => DbLayout(
    size: j['size'] as int,
    sha256: j['sha256'] as String,
    pageSize: j['page_size'] as int,
    blockSize: j['block_size'] as int,
    packs: [for (final p in j['packs'] as List) PackInfo.fromJson(p as Map<String, dynamic>)],
  );

  int get blockCount => (size + blockSize - 1) ~/ blockSize;

  /// Bytes of block [i] once inflated.
  int blockLength(int i) => i == blockCount - 1 ? size - i * blockSize : blockSize;

  /// Where block [i] is stored.
  ({int pack, int offset, int length}) block(int i) => (pack: _packOf[i], offset: _offsetOf[i], length: _lengthOf[i]);
}

class PackInfo {
  /// Path relative to the host root (`data/db/<sha16>.bin`).
  final String name;
  final int size;
  final String sha256;

  /// Compressed length of each block, in order.
  final List<int> blocks;
  const PackInfo({required this.name, required this.size, required this.sha256, required this.blocks});

  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(name: j['name'] as String, size: j['size'] as int, sha256: j['sha256'] as String, blocks: (j['blocks'] as List).cast<int>());
}
