/// Resolves a reading id to a [Reading]: ids below [userReadingBase] come from the content
/// database, ids from [userReadingBase] the user's own readings (Bài Nhập Của Bạn), ids from
/// [dialogReadingBase] a Luyện Nói dialog seen as a reading (A1, B1, A2, B2 …), so Nghe toàn
/// bài, Xếp từ and Nghe viết work on dialogs exactly as on readings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'content_db.dart';
import 'content_db_more.dart';
import 'models.dart';
import 'user_readings.dart';

const userReadingBase = 1000000;
const dialogReadingBase = 2000000;

Reading? loadReading(WidgetRef ref, int id) {
  if (id >= dialogReadingBase) return _dialogReading(ref.read(contentDbProvider), id);
  if (id >= userReadingBase) return ref.read(userDbProvider).userReading(id - userReadingBase)?.toReading();
  return ref.read(contentDbProvider).reading(id);
}

Reading? loadReadingFrom(ProviderContainer c, int id) {
  if (id >= dialogReadingBase) return _dialogReading(c.read(contentDbProvider), id);
  if (id >= userReadingBase) return c.read(userDbProvider).userReading(id - userReadingBase)?.toReading();
  return c.read(contentDbProvider).reading(id);
}

/// Dialog `id - dialogReadingBase` as a TTS reading: one paragraph per A/B pair.
Reading? _dialogReading(ContentDb db, int id) {
  final d = db.dialog(id - dialogReadingBase);
  if (d == null) return null;
  final sentences = <Sentence>[];
  for (var p = 0; p < d.pairs.length; p++) {
    sentences.add(Sentence(sentences.length, p, d.pairs[p].a, d.pairs[p].avi));
    sentences.add(Sentence(sentences.length, p, d.pairs[p].b, d.pairs[p].bvi));
  }
  return Reading(id: id, sid: -1, position: 0, title: d.title, img: db.dialogPageImage(d.id), titleAudio: false, sentences: sentences);
}
