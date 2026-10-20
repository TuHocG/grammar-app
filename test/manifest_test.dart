// Parsing of data/latest.json and data/<version>/manifest.json (tool/content/host.py).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/manifest.dart';

const _manifest = {
  'format': 1,
  'content_version': '1.2.0',
  'schema': 1,
  'date': '2026-10-20',
  'variant': 'web',
  'db': {
    'size': 100000, // 1 full block of 65536 + a last block of 34464
    'sha256': 'abc',
    'page_size': 4096,
    'block_size': 65536,
    'packs': [
      {
        'name': 'data/db/aaaa.bin',
        'size': 30,
        'sha256': 'p0',
        'blocks': [30],
      },
      {
        'name': 'data/db/bbbb.bin',
        'size': 20,
        'sha256': 'p1',
        'blocks': [20],
      },
    ],
  },
  'images': {
    'img/readings/x.webp': [1234, 'deadbeef'],
  },
};

void main() {
  test('latest.json', () {
    final l = HostLatest.parse('{"version": "1.2.0", "schema": 1, "manifest": "data/1.2.0/manifest.json"}');
    expect(l.version, '1.2.0');
    expect(l.schema, 1);
    expect(l.manifest, 'data/1.2.0/manifest.json');
  });

  test('manifest: blocks are located across packs', () {
    final m = HostManifest.parse(jsonEncode(_manifest));
    expect(m.contentVersion, '1.2.0');
    expect(m.variant, 'web');
    expect(m.images['img/readings/x.webp']!.size, 1234);
    expect(m.images['img/readings/x.webp']!.sha8, 'deadbeef');
    expect(m.db.blockCount, 2);
    expect(m.db.block(0), (pack: 0, offset: 0, length: 30));
    expect(m.db.block(1), (pack: 1, offset: 0, length: 20));
    expect(m.db.blockLength(0), 65536);
    expect(m.db.blockLength(1), 34464);
  });

  test('manifest: offsets inside a pack add up', () {
    final j = jsonDecode(jsonEncode(_manifest)) as Map<String, dynamic>;
    (j['db'] as Map)['packs'] = [
      {
        'name': 'p',
        'size': 50,
        'sha256': '',
        'blocks': [30, 20],
      },
    ];
    final db = DbLayout.fromJson(j['db'] as Map<String, dynamic>);
    expect(db.block(1), (pack: 0, offset: 30, length: 20));
  });

  test('manifest: a pack whose blocks do not fill it, or a wrong block count, is rejected', () {
    final j = jsonDecode(jsonEncode(_manifest)) as Map<String, dynamic>;
    ((j['db'] as Map)['packs'] as List)[0] = {
      'name': 'p',
      'size': 31,
      'sha256': '',
      'blocks': [30],
    };
    expect(() => DbLayout.fromJson(j['db'] as Map<String, dynamic>), throwsFormatException);
    final k = jsonDecode(jsonEncode(_manifest)) as Map<String, dynamic>;
    (k['db'] as Map)['size'] = 200000; // needs 4 blocks, 2 listed
    expect(() => DbLayout.fromJson(k['db'] as Map<String, dynamic>), throwsFormatException);
  });

  test('a newer manifest format is refused as such, even when its structure differs', () {
    final j = jsonDecode(jsonEncode(_manifest)) as Map<String, dynamic>;
    j['format'] = HostManifest.supportedFormat + 1;
    j['db'] = 'something else';
    expect(() => HostManifest.parse(jsonEncode(j)), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('manifest format 2'))));
  });

  test('malformed input is a FormatException, never a TypeError', () {
    expect(() => HostManifest.parse('[]'), throwsFormatException);
    expect(() => HostManifest.parse('{"format": 1, "db": 5}'), throwsFormatException);
    expect(() => HostManifest.parse('{"format": "1"}'), throwsFormatException);
    expect(() => HostLatest.parse('{"version": 1}'), throwsFormatException);
    expect(() => HostLatest.parse('nope'), throwsFormatException);
    final j = jsonDecode(jsonEncode(_manifest)) as Map<String, dynamic>;
    (j['db'] as Map)['block_size'] = 1000; // not a multiple of the page size
    expect(() => HostManifest.parse(jsonEncode(j)), throwsFormatException);
  });
}
