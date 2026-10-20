// The release layout (grammar.db + grammar.images + audio/ side by side, from tool/content/bundle.py) and the
// repo layout (content/grammar.db + dataset/) must both work. Run after bundle.py, which writes both
// files into build/content (skipped otherwise).
import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';
import 'package:grammar/data/image_pack.dart';
import 'package:grammar/data/media_locations.dart';
import 'package:path/path.dart' as p;

void main() {
  final bundle = Platform.environment['GRAMMAR_BUNDLE_DIR'] ?? 'build/content';
  final hasBundle = File('$bundle/grammar.db').existsSync();
  final hasWeb = File('$bundle/web/grammar.db').existsSync();
  final repo = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final hasRepo = File('$repo/grammar.db').existsSync();

  test('release bundle: pages from the database, illustrations from grammar.images, audio next to it', () {
    final db = ContentDb.open(bundle);
    expect(db.schemaVersion, 1);
    expect(db.variant, 'full');
    expect(db.hasVideo, isTrue);
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
    expect(db.imageProvider(img), db.imageProvider(img)); // one image-cache key per picture
    expect(db.images!.read(img)!.sublist(8, 12), 'WEBP'.codeUnits);
    expect(db.imagePackError, isNull);
    final dir = defaultAudioDir(db);
    expect(dir.endsWith('audio'), isTrue);
    expect(p.normalize(defaultVideoDir(db)), p.normalize(p.join(bundle, 'video')));
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

  test('web variant (bundle.py --web): no video, no embedded pages, same lessons', () {
    final web = ContentDb.open('$bundle/web');
    addTearDown(web.close);
    final full = ContentDb.open(bundle);
    addTearDown(full.close);
    expect(web.schemaVersion, 1);
    expect(web.variant, 'web');
    expect(web.hasVideo, isFalse);
    expect(web.embeddedMediaCount, 0);
    expect(web.counts.containsKey('subtitle_film'), isFalse);
    expect(web.counts['media'], isNull);
    for (final k in ['dict_entry', 'reading', 'reading_sentence', 'dialog', 'grammar_lesson', 'exercise', 'picture_topic', 'listening_item']) {
      expect(web.counts[k], full.counts[k], reason: k);
    }
    // The pages are plain pictures there: bundle.py --web copies them to web/img/pages/.
    for (final t in web.pictureTopics()) {
      expect(web.embeddedMedia(t.page!), isNull);
      expect(web.imageProvider(t.page!), isA<FileImage>());
      expect(web.mediaFile(t.page!).existsSync(), isTrue, reason: t.page);
    }
    expect(web.searchPrefix('hello').first.headword, full.searchPrefix('hello').first.headword);
  }, skip: !hasBundle || !hasWeb);

  testWidgets('an illustration decodes straight from grammar.images', (tester) async {
    final db = ContentDb.open(bundle);
    addTearDown(db.close);
    final img = db.raw.select('SELECT img FROM reading WHERE img IS NOT NULL LIMIT 1').first['img'] as String;
    final provider = db.imageProvider(img);
    expect(provider, isA<PackImage>());
    late final ImageInfo info;
    await tester.runAsync(() async {
      final done = Completer<void>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((i, _) {
              info = i;
              done.complete();
            }, onError: (e, _) => done.completeError(e)),
          );
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
