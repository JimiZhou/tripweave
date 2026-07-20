import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/src/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native video import keeps picker path instead of loading the file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tripweave-import-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/large-video.mp4');
      await file.writeAsBytes(List<int>.filled(1024 * 1024, 7));

      final state = AppState();
      await state.importMediaFiles([
        XFile(file.path, name: 'large-video.mp4', mimeType: 'video/mp4'),
      ]);

      expect(state.assets, hasLength(1));
      expect(state.assets.single.bytes, isEmpty);
      expect(state.assets.single.sourcePath, file.path);
      expect(state.assets.single.byteLength, 1024 * 1024);
    },
  );
}
