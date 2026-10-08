// The release layout (grammar.db + grammar-images.zip + audio/ side by side, from tool/content/bundle.py) and the
// repo layout (content/grammar.db + dataset/) must both work. Run after bundle.py and unzipping into
// build/content/unzipped (skipped otherwise).
import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';
import 'package:grammar/data/image_pack.dart';
import 'package:grammar/data/media_locations.dart';

void main() {
  final bundle = Platform.environment['GRAMMAR_BUNDLE_DIR'] ?? 'build/content/unzipped';
  final hasBundle = File('$bundle/grammar.db').existsSync();
  // Encrypted bundle (bundle.py with GRAMMAR_DB_KEY): pass the same key to open it.
  final key = Platform.environment['GRAMMAR_BUNDLE_KEY'];
  final repo = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final hasRepo = File('$repo/grammar.db').existsSync();

  test('release bundle: pages from the database, illustrations from grammar-images.zip, audio next to it', () {
    final db = ContentDb.open(bundle, key: key);
    expect(db.schemaVersion, 1);
    final page = db.pictureTopics().first.page!;
    expect(db.embeddedMedia(page), isNotNull);
    expect(db.imageProvider(page), isA<MemoryImage>());
    expect(File('$bundle/dataset').existsSync() || Directory('$bundle/dataset').existsSync(), isFalse);
    expect(Directory('$bundle/img').existsSync(), isFalse);
    expect(db.images, isNotNull);
    // Every illustration the content refers to is in the pack.
    final imgs = [for (final r in db.raw.select('SELECT DISTINCT img FROM reading WHERE img IS NOT NULL')) r['img'] as String];
    expect(imgs.where((i) => !db.images!.contains(i)), isEmpty);
    final img = imgs.first;
    expect(db.imageProvider(img), isA<PackImage>());
    expect(db.imageProvider(img), db.imageProvider(img));   // one image-cache key per picture
    expect(db.images!.read(img)!.sublist(8, 12), 'WEBP'.codeUnits);
    expect(db.imagePackError, isNull);
    final dir = defaultAudioDir(db);
    expect(dir.endsWith('audio'), isTrue);
    if (Directory(dir).existsSync()) {
      final a = audioSummary(db, dir);
      expect(a.found, a.expected);
    }
    final s = dataSummary(db);
    expect(s.embedded, 155);
    expect(s.images, greaterThan(3000));
    expect(s.imagePack, isTrue);
    db.close();
  }, skip: !hasBundle);

  testWidgets('an illustration decodes straight from grammar-images.zip', (tester) async {
    final db = ContentDb.open(bundle, key: key);
    addTearDown(db.close);
    final img = db.raw.select('SELECT img FROM reading WHERE img IS NOT NULL LIMIT 1').first['img'] as String;
    final provider = db.imageProvider(img);
    expect(provider, isA<PackImage>());
    late final ImageInfo info;
    await tester.runAsync(() async {
      final done = Completer<void>();
      provider.resolve(ImageConfiguration.empty).addListener(ImageStreamListener((i, _) {
        info = i;
        done.complete();
      }, onError: (e, _) => done.completeError(e)));
      await done.future;
    });
    expect(info.image.width, greaterThan(0));
  }, skip: !hasBundle);

  test('repo layout still resolves dataset/img', () {
    final db = ContentDb.open(repo);
    final img = db.raw.select('SELECT img FROM reading WHERE img IS NOT NULL LIMIT 1').first['img'] as String;
    expect(db.mediaFile(img).existsSync(), isTrue);
    expect(db.mediaPath(img).contains('dataset'), isTrue);
    db.close();
  }, skip: !hasRepo);
}
