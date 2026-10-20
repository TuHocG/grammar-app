/// Read access to the user's own folders on Android (Download/…, SD card), where grammar.db,
/// img/, audio/ and the videos are read with plain file paths. Android 11+ grants this only
/// as "all files access" (a system settings page); Android 10 and older use the storage
/// permission. Other platforms need nothing.
library;

import 'package:flutter/foundation.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

enum StorageAccess {
  granted,

  /// Android 11+: the "all files access" settings page has to be switched on.
  needsAllFiles,

  /// Android 10 and older: the runtime storage prompt can still be shown.
  needsPrompt,

  /// Android 10 and older, denied for good: only the app's settings page can grant it.
  blocked,
}

PermissionHandlerPlatform get _handler => PermissionHandlerPlatform.instance;

Future<PermissionStatus> _request(Permission p) async => (await _handler.requestPermissions([p]))[p] ?? PermissionStatus.denied;

Future<StorageAccess> storageAccess() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return StorageAccess.granted;
  final all = await _handler.checkPermissionStatus(Permission.manageExternalStorage);
  if (all.isGranted) return StorageAccess.granted;
  // Below Android 11 "all files access" does not exist and reports restricted.
  if (!all.isRestricted) return StorageAccess.needsAllFiles;
  final legacy = await _handler.checkPermissionStatus(Permission.storage);
  if (legacy.isGranted) return StorageAccess.granted;
  return legacy.isPermanentlyDenied ? StorageAccess.blocked : StorageAccess.needsPrompt;
}

/// Shows the system page or prompt for [state]; true when access is granted afterwards.
Future<bool> requestStorageAccess(StorageAccess state) async {
  switch (state) {
    case StorageAccess.granted:
      return true;
    case StorageAccess.needsAllFiles:
      return (await _request(Permission.manageExternalStorage)).isGranted;
    case StorageAccess.needsPrompt:
      return (await _request(Permission.storage)).isGranted;
    case StorageAccess.blocked:
      // The user comes back to the app on their own; the caller asks again next time.
      await _handler.openAppSettings();
      return false;
  }
}
