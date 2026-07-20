import 'dart:ffi';
import 'dart:io';

String? releasePlatformKey() {
  if (Platform.isAndroid) {
    return switch (Abi.current()) {
      Abi.androidArm64 => 'android-arm64',
      Abi.androidArm => 'android-armv7',
      Abi.androidX64 => 'android-x86_64',
      _ => 'android-arm64',
    };
  }
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  return null;
}
