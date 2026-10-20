import 'package:path_provider/path_provider.dart';

/// The user's Documents folder, where a save dialog starts; null when the platform has none.
Future<String?> documentsDir() async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    return null;
  }
}
