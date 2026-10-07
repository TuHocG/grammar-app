// The release layout (grammar.db + img/ + audio/ side by side, from tool/content/bundle.py) and the
// repo layout (content/grammar.db + dataset/) must both work. Run after bundle.py and unzipping into
// build/content/unzipped (skipped otherwise).
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';
import 'package:grammar/data/media_locations.dart';
import 'package:path/path.dart' as p;

void main() {
  final bundle = Platform.environment['GRAMMAR_BUNDLE_DIR'] ?? 'build/content/unzipped';
  final hasBundle = File('$bundle/grammar.db').existsSync();
  final repo = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final hasRepo = File('$repo/grammar.db').existsSync();

  test('release bundle: pages from the database, illustrations and audio next to it', () {
    final db = ContentDb.open(bundle);
    expect(db.schemaVersion, 1);
    final page = db.pictureTopics().first.page!;
    expect(db.embeddedMedia(page), isNotNull);
    expect(db.imageProvider(page), isA<MemoryImage>());
    expect(File('$bundle/dataset').existsSync() || Directory('$bundle/dataset').existsSync(), isFalse);
    final img = db.raw.select('SELECT img FROM reading WHERE img IS NOT NULL LIMIT 1').first['img'] as String;
    expect(p.normalize(db.mediaPath(img)), p.normalize(p.join(bundle, img)));
    expect(db.mediaFile(img).existsSync(), isTrue);
    expect(db.imageProvider(img), isA<FileImage>());
    final dir = defaultAudioDir(db);
    expect(dir.endsWith('audio'), isTrue);
    final a = audioSummary(db, dir);
    expect(a.found, a.expected);
    final s = dataSummary(db);
    expect(s.embedded, 155);
    expect(s.images, greaterThan(3000));
    db.close();
  }, skip: !hasBundle);

  test('repo layout still resolves dataset/img', () {
    final db = ContentDb.open(repo);
    final img = db.raw.select('SELECT img FROM reading WHERE img IS NOT NULL LIMIT 1').first['img'] as String;
    expect(db.mediaFile(img).existsSync(), isTrue);
    expect(db.mediaPath(img).contains('dataset'), isTrue);
    db.close();
  }, skip: !hasRepo);
}
