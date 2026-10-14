import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/data/user_readings.dart';

void main() {
  test('Vietnamese sentences starting with a non-ASCII capital split', () {
    expect(
      splitText('Lúc 12 giờ trưa, chúng tôi ăn trưa cùng nhau. Đôi khi chúng tôi ăn ở quán. Ở nhà thì nấu.'),
      [['Lúc 12 giờ trưa, chúng tôi ăn trưa cùng nhau.', 'Đôi khi chúng tôi ăn ở quán.', 'Ở nhà thì nấu.']],
    );
  });

  test('English and Vietnamese paragraphs give the same sentence counts', () {
    const en = 'At 12:00 PM, we have lunch together. Sometimes we eat at a small restaurant nearby, but often we bring food from home. '
        'After lunch, I continue working until 5:00 PM.\n\nIn the evening, I cook dinner. 10:30 PM is bedtime.';
    const vi = 'Lúc 12 giờ trưa, chúng tôi ăn trưa cùng nhau. Đôi khi chúng tôi ăn ở một quán nhỏ gần đó, nhưng thường mang cơm từ nhà. '
        'Sau giờ ăn trưa, tôi tiếp tục làm việc đến 5 giờ chiều.\n\nBuổi tối, tôi nấu bữa tối. 10 giờ 30 là giờ đi ngủ.';
    expect(splitText(en).map((p) => p.length), [3, 2]);
    expect(splitText(vi).map((p) => p.length), [3, 2]);
  });

  test('"_" overrides punctuation splitting', () {
    expect(splitText('Mr. Smith came. He sat_Then left.'), [['Mr. Smith came. He sat', 'Then left.']]);
  });
}
