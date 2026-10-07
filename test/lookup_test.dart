// Runs against the real dist/grammar.db when it exists (skipped otherwise).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/content_db_more.dart';
import 'package:grammar/data/search_key.dart';
import 'package:grammar/domain/lookup.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late LookupService lookup;

  setUpAll(() {
    if (!has) return;
    db = ContentDb.open(dir);
    lookup = LookupService(db);
  });
  tearDownAll(() {
    if (has) db.close();
  });

  test('quick def + full entry for "ball"', () {
    final r = lookup.lookup('ball.');
    expect(r.found, isTrue);
    expect(r.quick?.vi, 'quả bóng');
    expect(r.quick?.respell, isNotEmpty);
    expect(r.entries.first.ipa, 'bɔ:l');
    expect(r.entries.first.segs.first.kind, 'pos');
  }, skip: !has);

  test('Xem#x# redirect: abaci -> abacus', () {
    final r = lookup.lookup('abaci');
    expect(r.redirectedFrom, 'abaci');
    expect(r.headword, 'abacus');
  }, skip: !has);

  test('quick meaning of the exact word wins over its Xem#x# redirect: heard', () {
    final r = lookup.lookup('heard');
    expect(r.headword, 'heard');
    expect(r.key, 'heard');
    expect(r.quick?.vi, 'đã nghe (quá khứ của Hear)');
    expect(r.ipa, 'hə:d');
    expect(r.entries.first.headword, 'hear');   // full entry borrowed from the target
    expect(r.entryHeadword, 'hear');
    expect(r.redirectedFrom, isNull);
  }, skip: !has);

  test('inflected form falls back to the base form', () {
    final r = lookup.lookup('abandonning');   // not a headword; doubled consonant + -ing
    expect(r.found, isTrue);
    expect(r.key, 'abandon');
  }, skip: !has);

  test('phrase with an inflected verb: "came through" -> "come through"', () {
    final r = lookup.lookup('came through');
    expect(r.headword, 'come through');
    expect(r.entries.first.key, 'come through');
  }, skip: !has);

  test('phrase shrinks from the end: "came through them" -> "come through"', () {
    final r = lookup.lookup('came through them');
    expect(r.headword, 'come through');
  }, skip: !has);

  test('irregular single word falls back to its base when it has no entry', () {
    expect(baseFormCandidates('went').first, 'go');
    expect(baseFormCandidates('heard').first, 'hear');
  }, skip: !has);

  test('related forms for "unit"', () {
    final r = lookup.lookup('unit');
    expect(r.family, isNotNull);
    expect(r.family!.members.map((m) => m.word), contains('subunit'));
  }, skip: !has);

  test('prefix search is ordered and fast', () {
    final sw = Stopwatch()..start();
    final hits = db.around('aban', before: 3, after: 50);
    sw.stop();
    expect(hits.any((h) => h.key == 'abandon'), isTrue);
    expect(sw.elapsedMilliseconds, lessThan(200));
  }, skip: !has);

  test('listening unit reuses the recording of the matching reading', () {
    final r = db.listeningReading(1);
    expect(r, isNotNull);
    expect(r!.audio, 'audio/1.mp3');
    expect(r.hasRealAudio, isTrue);
    final first = db.listeningItems(1).firstWhere((i) => i.n == 1);
    expect(r.sentences[0].en, first.en);
    expect(db.listeningReading(2)!.audio, 'audio/2.wav');
  }, skip: !has);

  test('counts match the ETL manifest', () {
    expect(db.counts['dict_entry'], 544266);
    expect(db.helpTopics().length, 30);
  }, skip: !has);
}
