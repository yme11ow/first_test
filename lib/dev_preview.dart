import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';

/// Wraps the app in a simulated iPhone when developing in Chrome on Windows.
/// Does nothing in release builds (TestFlight / App Store) or on a real phone.
/// Change device / dark mode / text size from the "device_preview" tab in DevTools.
void setUpDevPreview() {
  final enabled = kDebugMode && kIsWeb;
  DevicePreview.enable(enabled: enabled);
  if (enabled) {
    DevicePreview.maybeController?.applyPreset(DevicePresets.iPhone17);
  }
}
