import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tripweave/src/editing_agent_models.dart';
import 'package:tripweave/src/models.dart';
import 'package:tripweave/src/render_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'FFmpeg backend renders and validates video with synthetic audio',
    () async {
      final backend = createRenderBackend();
      if (await backend.availability() != null) return;

      MediaItem makeAsset(String id, img.Color color) {
        final image = img.Image(width: 320, height: 240);
        img.fill(image, color: color);
        final bytes = Uint8List.fromList(img.encodeJpg(image));
        return MediaItem(
          id: id,
          name: '$id.jpg',
          kind: MediaKind.image,
          bytes: bytes,
          importedAt: DateTime(2026),
          byteLength: bytes.length,
          width: 320,
          height: 240,
        );
      }

      final assets = [
        makeAsset('warm', img.ColorRgb8(205, 83, 52)),
        makeAsset('moss', img.ColorRgb8(82, 100, 77)),
      ];
      final plan = AgentEditPlan(
        title: 'Render smoke',
        style: 'postcard',
        ratio: VlogRatio.landscape,
        musicId: 'city-run',
        clips: const [
          AgentClipPlan(mediaId: 'warm', durationMs: 1200, caption: ''),
          AgentClipPlan(mediaId: 'moss', durationMs: 1200, caption: ''),
        ],
      );

      final stopwatch = Stopwatch()..start();
      final output = await backend.render(
        plan: plan,
        assets: assets,
        musicBytes: _silentWave(),
      );
      stopwatch.stop();
      expect(await File(output).exists(), isTrue);
      final validation = await backend.validate(output);
      expect(validation, contains('h264'));
      expect(validation, contains('aac'));
      final report = jsonDecode(validation) as Map<String, dynamic>;
      final metadata = report['tripweave'] as Map<String, dynamic>;
      expect(metadata['encoder'], isNot('unknown'));
      expect(metadata['hardware'], isA<bool>());
      debugPrint(
        '[render-benchmark] encoder=${metadata['encoder']} '
        'hardware=${metadata['hardware']} elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Uint8List _silentWave() {
  const sampleRate = 48000;
  const channels = 2;
  const bitsPerSample = 16;
  const sampleCount = sampleRate;
  const dataLength = sampleCount * channels * (bitsPerSample ~/ 8);
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);

  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  return bytes;
}
