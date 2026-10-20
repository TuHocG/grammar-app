import 'package:flutter/painting.dart';

import '../data/media_store.dart';

ImageProvider userImage(String ref) => const NoMedia().image(ref);

bool userImageExists(String ref) => false;

Future<String?> pickUserImage({required String current}) async => null;
