import 'dart:typed_data';

import 'editing_agent_models.dart';
import 'models.dart';
import 'render_backend_base.dart';

RenderBackend createRenderBackend() => const UnsupportedRenderBackend();

class UnsupportedRenderBackend extends RenderBackend {
  const UnsupportedRenderBackend();

  @override
  Future<String?> availability() async =>
      '当前 Web 构建尚未加载 ffmpeg.wasm 渲染适配器。Agent 可以完成素材理解和剪辑计划，但不能在浏览器内编码 MP4。';

  @override
  Future<Uint8List?> extractVideoFrame(MediaItem asset) async => null;

  @override
  Future<String> render({
    required AgentEditPlan plan,
    required List<MediaItem> assets,
    Uint8List? musicBytes,
    void Function(double progress)? onProgress,
  }) {
    throw UnsupportedError('当前平台没有可用的 FFmpeg 渲染后端。');
  }

  @override
  Future<String> validate(String outputPath) {
    throw UnsupportedError('当前平台没有可用的 FFprobe 验证后端。');
  }
}
