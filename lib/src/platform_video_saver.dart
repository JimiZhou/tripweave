import 'platform_video_saver_stub.dart'
    if (dart.library.io) 'platform_video_saver_io.dart';

/// Saves an already-rendered video to the platform media library when the
/// platform provides a direct system destination (currently Android).
///
/// Returns a platform location/URI when handled, or `null` when the caller
/// should fall back to the desktop/web save dialog.
Future<String?> saveVideoToSystemLibrary({
  required String sourcePath,
  required String suggestedName,
}) => saveVideoToSystemLibraryImpl(
  sourcePath: sourcePath,
  suggestedName: suggestedName,
);
