import 'package:flutter/widgets.dart';

import 'app/bootstrap.dart';

/// Opens the databases and runs the app; how depends on the platform (`app/bootstrap_*.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
}
