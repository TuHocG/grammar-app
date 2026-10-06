/// Resolves a reading id to a [Reading]: ids below [userReadingBase] come from the content
/// database, ids at or above it from the user's own readings (Bài Nhập Của Bạn).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'content_db.dart';
import 'models.dart';
import 'user_readings.dart';

const userReadingBase = 1000000;

Reading? loadReading(WidgetRef ref, int id) {
  if (id >= userReadingBase) return ref.read(userDbProvider).userReading(id - userReadingBase)?.toReading();
  return ref.read(contentDbProvider).reading(id);
}

Reading? loadReadingFrom(ProviderContainer c, int id) {
  if (id >= userReadingBase) return c.read(userDbProvider).userReading(id - userReadingBase)?.toReading();
  return c.read(contentDbProvider).reading(id);
}
