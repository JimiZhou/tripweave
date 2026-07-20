import 'dart:io';
import 'dart:typed_data';

Future<bool> sourceFileExists(String? path) async {
  if (path == null || path.trim().isEmpty) return false;
  return File(path).exists();
}

Future<Uint8List> readSourceFile(String path) => File(path).readAsBytes();
