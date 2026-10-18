// grammar.images reader: stored entries (what bundle.py writes) and deflated ones (a folder
// re-zipped with an ordinary tool), names in UTF-8, directories skipped, a broken file ignored.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/image_pack.dart';

/// Minimal zip writer for the test (CRC left 0: the reader does not check it). [streamed]
/// writes the way a non-seekable writer does: flag 8 and zero sizes in the local headers, the
/// real sizes only in the central directory (and a data descriptor after each entry).
Uint8List zip(Map<String, (List<int>, bool)> files, {String comment = '', bool streamed = false}) {
  final out = BytesBuilder();
  final dir = BytesBuilder();
  void u16(BytesBuilder b, int v) => b.add([v & 0xff, v >> 8 & 0xff]);
  void u32(BytesBuilder b, int v) => b.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
  for (final MapEntry(key: name, value: (data, deflate)) in files.entries) {
    final n = utf8.encode(name);
    final body = deflate ? ZLibEncoder(raw: true).convert(data) : data;
    final offset = out.length;
    u32(out, 0x04034b50);
    u16(out, 20);
    u16(out, streamed ? 0x808 : 0x800);
    u16(out, deflate ? 8 : 0);
    u32(out, 0);
    u32(out, 0);
    u32(out, streamed ? 0 : body.length);
    u32(out, streamed ? 0 : data.length);
    u16(out, n.length);
    u16(out, 3);
    out.add(n);
    out.add([1, 2, 3]); // extra field, skipped by its length
    out.add(body);
    if (streamed) {
      u32(out, 0x08074b50);
      u32(out, 0);
      u32(out, body.length);
      u32(out, data.length);
    }
    u32(dir, 0x02014b50);
    u16(dir, 20);
    u16(dir, 20);
    u16(dir, 0x800);
    u16(dir, deflate ? 8 : 0);
    u32(dir, 0);
    u32(dir, 0);
    u32(dir, body.length);
    u32(dir, data.length);
    u16(dir, n.length);
    u16(dir, 0);
    u16(dir, 0);
    u16(dir, 0);
    u16(dir, 0);
    u32(dir, 0);
    u32(dir, offset);
    dir.add(n);
  }
  final dirOffset = out.length;
  final d = dir.takeBytes();
  out.add(d);
  final c = utf8.encode(comment);
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, files.length);
  u16(out, files.length);
  u32(out, d.length);
  u32(out, dirOffset);
  u16(out, c.length);
  out.add(c);
  return out.takeBytes();
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('image_pack'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('reads stored and deflated entries by content path', () {
    final big = List.generate(5000, (i) => i % 7);
    final f = File('${tmp.path}/$imagePackName')
      ..writeAsBytesSync(
        zip({
          'img/readings/': (<int>[], false),
          'img/readings/1.webp': (utf8.encode('RIFF....WEBP one'), false),
          'img/readings/Saint_-_Médard..webp': (utf8.encode('accented'), false),
          'img/dialogs/CANBAN1.webp': (big, true),
        }, comment: 'made by a test'),
      );
    final pack = ImagePack.open(f.path)!;
    addTearDown(pack.close);
    expect(pack.length, 3); // the directory entry is not counted
    expect(utf8.decode(pack.read('img/readings/1.webp')!), 'RIFF....WEBP one');
    expect(utf8.decode(pack.read('img/readings/Saint_-_Médard..webp')!), 'accented');
    expect(pack.read('img/dialogs/CANBAN1.webp'), big);
    expect(pack.read('img/readings/missing.webp'), isNull);
    expect(pack.contains('img/readings/1.webp'), isTrue);
  });

  test('sizes from the central directory when the local headers have none', () {
    final f = File('${tmp.path}/streamed.zip')..writeAsBytesSync(zip({'img/a.webp': (utf8.encode('first'), true), 'img/b.webp': (utf8.encode('second'), false)}, streamed: true));
    final pack = ImagePack.open(f.path)!;
    addTearDown(pack.close);
    expect(utf8.decode(pack.read('img/a.webp')!), 'first');
    expect(utf8.decode(pack.read('img/b.webp')!), 'second');
  });

  test('a missing file is no pack; a broken one says so', () {
    expect(ImagePack.open('${tmp.path}/none.zip'), isNull);
    final junk = File('${tmp.path}/junk.zip')..writeAsStringSync('not a zip at all');
    expect(() => ImagePack.open(junk.path), throwsFormatException);
  });

  test('an entry cut short is an error, not half a picture', () {
    final whole = zip({'img/a.webp': (List.filled(1000, 7), false)});
    final f = File('${tmp.path}/short.zip')..writeAsBytesSync(whole);
    final pack = ImagePack.open(f.path)!;
    addTearDown(pack.close);
    f.writeAsBytesSync(whole.sublist(0, 600)); // the download stopped half-way
    expect(() => pack.read('img/a.webp'), throwsFormatException);
  });

  test('PackImage is keyed by pack and entry, so the image cache reuses decoded pictures', () {
    final f = File('${tmp.path}/$imagePackName')
      ..writeAsBytesSync(
        zip({
          'img/a.webp': (<int>[1], false),
        }),
      );
    final pack = ImagePack.open(f.path)!;
    addTearDown(pack.close);
    expect(PackImage(pack, 'img/a.webp'), PackImage(pack, 'img/a.webp'));
    expect(PackImage(pack, 'img/a.webp') == PackImage(pack, 'img/b.webp'), isFalse);
  });
}
