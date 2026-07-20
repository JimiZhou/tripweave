import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.tripweave.tripweave/media_store');

Future<String?> saveVideoToSystemLibraryImpl({
  required String sourcePath,
  required String suggestedName,
}) async {
  if (!Platform.isAndroid || sourcePath.startsWith('data:')) return null;
  final file = File(sourcePath);
  if (!await file.exists()) {
    throw StateError('导出的临时视频不存在，请重新生成后再保存。');
  }
  return _channel.invokeMethod<String>('saveVideo', {
    'sourcePath': sourcePath,
    'displayName': suggestedName,
  });
}
