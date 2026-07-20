import 'dart:typed_data';

import 'editing_agent_models.dart';
import 'models.dart';

abstract class RenderBackend {
  const RenderBackend();

  Future<String?> availability();

  Future<Uint8List?> extractVideoFrame(MediaItem asset);

  Future<String> render({
    required AgentEditPlan plan,
    required List<MediaItem> assets,
    Uint8List? musicBytes,
    void Function(double progress)? onProgress,
  });

  Future<String> validate(String outputPath);
}
