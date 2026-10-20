// The web host layout written by tool/content/host.py (build/host, from bundle.py --host): the
// manifest matches the files, the packs reassemble into the database the app opens, and every
// picture the content refers to is there. Skipped until build/host exists.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/block_vfs.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';
import 'package:grammar/data/manifest.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final host = Platform.environment['GRAMMAR_HOST_DIR'] ?? 'build/host';
  final has = File('$host/data/latest.json').existsSync();

  late HostLatest latest;
  late HostManifest manifest;
  late List<Uint8List> packs;
  setUpAll(() {
    if (!has) return;
    latest = HostLatest.parse(File('$host/data/latest.json').readAsStringSync());
    manifest = HostManifest.parse(File('$host/${latest.manifest}').readAsStringSync());
    packs = [for (final p in manifest.db.packs) File('$host/${p.name}').readAsBytesSync()];
  });

  test('latest.json points at a manifest of the same version and schema', () {
    expect(manifest.contentVersion, latest.version);
    expect(manifest.schema, latest.schema);
    expect(manifest.schema, lessThanOrEqualTo(ContentDb.supportedSchema));
    expect(manifest.variant, 'web');
  }, skip: !has);

  test('every pack has the size and sha256 of the manifest', () {
    for (var i = 0; i < packs.length; i++) {
      expect(packs[i].length, manifest.db.packs[i].size, reason: manifest.db.packs[i].name);
      expect(sha256.convert(packs[i]).toString(), manifest.db.packs[i].sha256, reason: manifest.db.packs[i].name);
    }
  }, skip: !has);

  test('the packs reassemble into the database, which opens as the web variant', () {
    final source = PackedBlockSource(manifest.db, packs);
    final whole = BytesBuilder(copy: false);
    for (var i = 0; i < manifest.db.blockCount; i++) {
      whole.add(source.block(i));
    }
    final bytes = whole.takeBytes();
    expect(bytes.length, manifest.db.size);
    expect(sha256.convert(bytes).toString(), manifest.db.sha256);

    final db = ContentDb.fromDatabase(BlockVfs(PackedBlockSource(manifest.db, packs), name: 'host-test').open(sqlite3));
    addTearDown(db.close);
    expect(db.variant, 'web');
    expect(db.contentVersion, manifest.contentVersion);
    expect(db.hasVideo, isFalse);
    expect(db.embeddedMediaCount, 0);
    // Every picture the lessons use is on the host: illustrations, Luyện Nói pages, picture pages.
    final needed = <String>{
      for (final r in db.raw.select('SELECT DISTINCT img FROM reading WHERE img IS NOT NULL')) r['img'] as String,
      for (final t in db.pictureTopics()) t.page!,
      ...(jsonDecode(db.raw.select("SELECT value FROM meta WHERE key = 'dialog_images'").first['value'] as String) as List).cast<String>(),
    };
    final missing = needed.where((rel) => !manifest.images.containsKey(rel)).toList();
    expect(missing, isEmpty);
    for (final rel in needed.take(50)) {
      final f = File('$host/$rel');
      expect(f.existsSync(), isTrue, reason: rel);
      expect(f.lengthSync(), manifest.images[rel]!.size, reason: rel);
    }
  }, skip: !has);

  test('within the limits of the free host: under 20,000 files, none over 25 MiB', () {
    final files = Directory(host).listSync(recursive: true).whereType<File>().toList();
    expect(files.length, lessThan(20000));
    expect(files.where((f) => f.lengthSync() > 25 * 1024 * 1024), isEmpty);
  }, skip: !has);
}
