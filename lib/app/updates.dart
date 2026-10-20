/// A newer content version the host offers (web app, docs/07 §12): its version, or null. Set by
/// the web bootstrap after a background check; the home page shows a card that leads to Cài Đặt.
library;

import 'package:flutter/foundation.dart';

final availableContentUpdate = ValueNotifier<String?>(null);
