// The block VFS (lib/data/block_vfs.dart) must read a database cut into deflated packs exactly
// as the native library reads the file. The packs are built here, the way tool/content/host.py
// builds them, from content/grammar.db (skipped when it is missing).
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoderWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/block_vfs.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';
import 'package:grammar/data/manifest.dart';
import 'package:sqlite3/sqlite3.dart';

const blockSize = 64 * 1024;

/// Deflates [bytes] block by block into packs of about [packBytes], like host.py.
(DbLayout, List<Uint8List>) packBytes(Uint8List bytes, {int packBytes = 8 << 20}) {
  final deflate = ZLibEncoder(raw: true, level: 1);
  final packs = <Uint8List>[];
  final infos = <PackInfo>[];
  var cur = BytesBuilder(copy: false);
  var lengths = <int>[];
  void flush() {
    if (lengths.isEmpty) return;
    final data = cur.takeBytes();
    packs.add(data);
    infos.add(PackInfo(name: 'pack${infos.length}', size: data.length, sha256: '', blocks: lengths));
    cur = BytesBuilder(copy: false);
    lengths = [];
  }

  for (var off = 0; off < bytes.length; off += blockSize) {
    final end = off + blockSize < bytes.length ? off + blockSize : bytes.length;
    final z = deflate.convert(Uint8List.sublistView(bytes, off, end));
    if (cur.length > 0 && cur.length + z.length > packBytes) flush();
    cur.add(z);
    lengths.add(z.length);
  }
  flush();
  return (DbLayout(size: bytes.length, sha256: '', pageSize: 4096, blockSize: blockSize, packs: infos), packs);
}

/// The pure-Dart inflate the browser runs (the VM otherwise goes through dart:io's zlib).
Uint8List inflateInDart(Uint8List z) => const ZLibDecoderWeb().decodeBytes(z, raw: true);

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final file = File('$dir/grammar.db');
  final has = file.existsSync();

  late Uint8List bytes;
  late DbLayout layout;
  late List<Uint8List> packs;
  late ContentDb direct;
  setUpAll(() {
    if (!has) return;
    bytes = file.readAsBytesSync();
    (layout, packs) = packBytes(bytes);
    direct = ContentDb.open(dir);
  });
  tearDownAll(() {
    if (has) direct.close();
  });

  /// Opens the packed database; closed, and the VFS unregistered, when the test ends.
  ContentDb openBlocks(String name, {int cacheBytes = 16 << 20, Inflate inflate = inflateBlock}) {
    final vfs = BlockVfs(
      PackedBlockSource(layout, packs, cacheBytes: cacheBytes, inflate: inflate),
      name: name,
    );
    final db = ContentDb.fromDatabase(vfs.open(sqlite3));
    addTearDown(() {
      db.close();
      vfs.close();
    });
    return db;
  }

  test('the packs describe the whole file', () {
    expect(layout.blockCount, (bytes.length + blockSize - 1) ~/ blockSize);
    expect(layout.packs.length, greaterThan(1));
    expect(layout.block(0), (pack: 0, offset: 0, length: layout.packs[0].blocks[0]));
    expect(layout.block(layout.blockCount - 1).pack, layout.packs.length - 1);
    expect(layout.blockLength(layout.blockCount - 1), bytes.length - (layout.blockCount - 1) * blockSize);
  }, skip: !has);

  test('every query answers like the file does', () {
    final db = openBlocks('grammar-blocks-queries');
    expect(db.schemaVersion, direct.schemaVersion);
    expect(db.contentVersion, direct.contentVersion);
    expect(db.counts, direct.counts);
    for (final key in ['a', 'ab', 'abo', 'about', 'b', 'ball', 'zeb', 'hello', 'do', 'go', 'make']) {
      expect(direct.searchPrefix(key), isNotEmpty, reason: key);
      expect(db.searchPrefix(key).map((h) => h.headword).toList(), direct.searchPrefix(key).map((h) => h.headword).toList(), reason: key);
      expect(db.around(key).map((h) => h.id).toList(), direct.around(key).map((h) => h.id).toList(), reason: key);
    }
    expect(db.around('zzzz').map((h) => h.id).toList(), direct.around('zzzz').map((h) => h.id).toList()); // the end of the index
    for (final id in [1, 50, 538, 1000, 2500, 4660, 4693, 99999]) {
      final a = db.reading(id);
      final b = direct.reading(id);
      expect(a?.title, b?.title, reason: 'reading $id');
      expect(a?.sentences.map((s) => s.en).toList(), b?.sentences.map((s) => s.en).toList(), reason: 'reading $id');
    }
    expect(direct.reading(538), isNotNull);
    expect(db.sectionTree().children.length, direct.sectionTree().children.length);
    expect(direct.searchReadings('love'), isNotEmpty);
    expect(db.searchReadings('love').map((r) => r.id).toList(), direct.searchReadings('love').map((r) => r.id).toList());
    expect(db.exercisesInRange(1, 25).map((e) => e.id).toList(), direct.exercisesInRange(1, 25).map((e) => e.id).toList());
    expect(db.pictureTopics().map((t) => t.title).toList(), direct.pictureTopics().map((t) => t.title).toList());
    expect(direct.familyOf('happy'), isNotNull);
    expect(db.familyOf('happy')?.members.map((m) => m.word).toList(), direct.familyOf('happy')?.members.map((m) => m.word).toList());
    expect(db.grammarLessons().length, direct.grammarLessons().length);
    expect(db.dialogsInTopic(db.dialogTopics().first.sid).length, direct.dialogsInTopic(direct.dialogTopics().first.sid).length);
  }, skip: !has);

  test('quick_check reads every page through the VFS', () {
    final db = openBlocks('grammar-blocks-check');
    expect(db.raw.select('PRAGMA quick_check').first.values.first, 'ok');
  }, skip: !has);

  test('the pure-Dart inflate of the browser gives the same database', () {
    final db = openBlocks('grammar-blocks-dart', inflate: inflateInDart);
    expect(db.raw.select('PRAGMA quick_check').first.values.first, 'ok');
    expect(db.searchPrefix('ball').first.headword, direct.searchPrefix('ball').first.headword);
    expect(db.reading(538)!.sentences.length, direct.reading(538)!.sentences.length);
  }, skip: !has);

  test('a small cache keeps the most recently used blocks', () {
    final source = PackedBlockSource(layout, packs, cacheBytes: 4 * blockSize);
    Uint8List read(int i) => source.block(i);
    for (var i = 0; i < 5; i++) {
      expect(read(i), Uint8List.sublistView(bytes, i * blockSize, (i + 1) * blockSize), reason: 'block $i');
    }
    expect(source.misses, 5);
    expect(source.cachedBytes, 4 * blockSize); // 0 was evicted
    read(4);
    expect(source.misses, 5, reason: 'a hit');
    read(0);
    expect(source.misses, 6, reason: 'evicted, inflated again');
    read(2); // most recent now
    read(5); // evicts the least recent (3)
    read(2);
    expect(source.misses, 7);
    read(3);
    expect(source.misses, 8);
    expect(source.cachedBytes, lessThanOrEqualTo(4 * blockSize));
    // The last block is shorter than the others.
    final last = layout.blockCount - 1;
    expect(read(last), Uint8List.sublistView(bytes, last * blockSize));
  }, skip: !has);

  test('a database through a four-block cache still answers correctly', () {
    final db = openBlocks('grammar-blocks-small', cacheBytes: 4 * blockSize);
    expect(db.searchPrefix('ball').first.headword, direct.searchPrefix('ball').first.headword);
    expect(db.reading(538)!.sentences.length, direct.reading(538)!.sentences.length);
  }, skip: !has);

  test('reads past the end are short reads, zero-filled; writes are refused', () {
    final vfs = BlockVfs(PackedBlockSource(layout, packs), name: 'grammar-blocks-raw');
    final f = vfs.xOpen(Sqlite3Filename('/grammar.db'), SqlFlag.SQLITE_OPEN_MAIN_DB | SqlFlag.SQLITE_OPEN_READONLY).file;
    expect(f.xFileSize(), layout.size);
    final buf = Uint8List(100)..fillRange(0, 100, 7);
    expect(() => f.xRead(buf, layout.size - 10), throwsA(isA<VfsException>().having((e) => e.returnCode, 'code', SqlExtendedError.SQLITE_IOERR_SHORT_READ)));
    expect(buf.sublist(0, 10), Uint8List.sublistView(bytes, layout.size - 10));
    expect(buf.sublist(10), everyElement(0));
    final head = Uint8List(16);
    f.xRead(head, 0);
    expect(String.fromCharCodes(head.sublist(0, 15)), 'SQLite format 3');
    // A read spanning two blocks.
    final span = Uint8List(4096);
    f.xRead(span, blockSize - 2048);
    expect(span, Uint8List.sublistView(bytes, blockSize - 2048, blockSize + 2048));
    expect(() => f.xWrite(head, 0), throwsA(isA<VfsException>()));
    expect(() => vfs.xOpen(Sqlite3Filename('/grammar.db-journal'), SqlFlag.SQLITE_OPEN_MAIN_JOURNAL), throwsA(isA<VfsException>()));
    expect(vfs.xAccess('/grammar.db', 0), 1);
    expect(vfs.xAccess('/grammar.db', 1), 0); // SQLITE_ACCESS_READWRITE
    expect(vfs.xAccess('/grammar.db-wal', 0), 0);
  }, skip: !has);

  test('open twice is refused; close unregisters so the name can be reused', () {
    final vfs = BlockVfs(PackedBlockSource(layout, packs), name: 'grammar-blocks-again');
    final db = vfs.open(sqlite3);
    expect(() => vfs.open(sqlite3), throwsStateError);
    db.close();
    vfs.close();
    final db2 = vfs.open(sqlite3);
    expect(db2.select('SELECT COUNT(*) AS n FROM dict_entry').first['n'], direct.counts['dict_entry']);
    db2.close();
    vfs.close();
  }, skip: !has);
}
