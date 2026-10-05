import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/search_key.dart';

void main() {
  test('searchKey strips accents, case and extra spaces', () {
    expect(searchKey('  Việt  Nam '), 'viet nam');
    expect(searchKey('Ấn Độ'), 'an do');
    expect(searchKey("RENÉ"), 'rene');
  });
  test('cleanToken drops surrounding punctuation but keeps apostrophes', () {
    expect(cleanToken('"ball."'), 'ball');
    expect(cleanToken("don't,"), "don't");
    expect(cleanToken('(Mr.)'), 'Mr');
  });
  test('baseFormCandidates follows the old app order', () {
    expect(baseFormCandidates('kicked'), containsAllInOrder(['kick', 'kicke']));
    expect(baseFormCandidates('stopped'), contains('stop'));
    expect(baseFormCandidates('running'), contains('run'));
    expect(baseFormCandidates('cities'), contains('city'));
    expect(baseFormCandidates('boxes').first, 'box');
  });
}
