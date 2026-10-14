// Pages showing progress (home "continue" cards, exercise scores) refresh when a
// progress row changes, without an app restart (U5).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/data/user_db.dart';

void main() {
  late Directory tmp;
  late UserDb user;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('progress_rev');
    user = UserDb.open('${tmp.path}/user.db');
  });

  tearDown(() {
    user.close();
    tmp.deleteSync(recursive: true);
  });

  test('a changed or newly most-recent row bumps the revision; rewriting the newest does not', () async {
    final c = ProviderContainer(overrides: [userDbProvider.overrideWithValue(user)]);
    addTearDown(c.dispose);
    expect(c.read(progressRevisionProvider), 0);

    user.setProgress('reading', 'last_reading', '12');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(progressRevisionProvider), 1);

    user.setProgress('reading', 'last_reading', '12');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(progressRevisionProvider), 1);

    user.setProgress('exercise', 'menu0-g0', '{"pos":24,"score":20,"done":25}');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(progressRevisionProvider), 2);

    // Reopening the reading with the same value makes it the newest again: notify.
    user.setProgress('reading', 'last_reading', '12');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(progressRevisionProvider), 3);
  });
}
