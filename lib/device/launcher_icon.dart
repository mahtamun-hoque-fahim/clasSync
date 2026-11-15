import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The launcher icon's background follows the accent swatch: Android switches
/// it by enabling one activity alias per colour (LauncherIcon.kt on the
/// `classync/device` channel). Pending alert intents keep the alias component
/// they were created with, so the return value says whether a switch
/// happened and the caller re-runs the alert reschedule when it did.
const _device = MethodChannel('classync/device');

Future<bool> setLauncherIconAccent(String accent) async {
  if (kIsWeb || !Platform.isAndroid) return false;
  try {
    return await _device.invokeMethod<bool>('setIconAccent', accent) ?? false;
  } on PlatformException catch (e) {
    debugPrint('Could not switch the launcher icon: $e');
    return false;
  }
}
