import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'editing_agent_models.dart';
import 'models.dart';
import 'music_catalog.dart';
import 'render_backend_base.dart';

@JS('tripweaveRender')
external JSPromise<JSString> _tripweaveRender(
  JSString requestJson,
  JSFunction progressCallback,
);

@JS('tripweaveExtractFrame')
external JSPromise<JSString> _tripweaveExtractFrame(JSString requestJson);

RenderBackend createRenderBackend() => const WebFfmpegRenderBackend();

class WebFfmpegRenderBackend extends RenderBackend {
  const WebFfmpegRenderBackend();

  static final Map<String, Map<String, dynamic>> _renderMetadata = {};

  @override
  Future<String?> availability() async => null;

  @override
  Future<Uint8List?> extractVideoFrame(MediaItem asset) async {
    if (asset.kind != MediaKind.video) return null;
    final result = (await _tripweaveExtractFrame(
      jsonEncode({
        'extension': _safeExtension(asset),
        'base64': base64Encode(asset.bytes),
      }).toJS,
    ).toDart).toDart;
    return result.isEmpty ? null : base64Decode(result);
  }

  @override
  Future<String> render({
    required AgentEditPlan plan,
    required List<MediaItem> assets,
    Uint8List? musicBytes,
    void Function(double progress)? onProgress,
  }) async {
    final assetById = {for (final asset in assets) asset.id: asset};
    final dimensions = switch (plan.ratio) {
      VlogRatio.portrait => (720, 1280),
      VlogRatio.landscape => (1280, 720),
      VlogRatio.square => (960, 960),
    };
    final musicData = musicBytes ?? await MusicCatalog.loadBytes(plan.musicId);
    final inputs = <Map<String, dynamic>>[];
    for (final clip in plan.clips) {
      final asset = assetById[clip.mediaId];
      if (asset == null) throw StateError('剪辑计划引用了不存在的素材。');
      inputs.add({
        'kind': asset.kind.name,
        'extension': _safeExtension(asset),
        'startMs': clip.startMs,
        'durationMs': clip.durationMs,
        'base64': base64Encode(asset.bytes),
      });
    }
    final payload = <String, dynamic>{
      'width': dimensions.$1,
      'height': dimensions.$2,
      'totalDurationMs': plan.totalDurationMs,
      'musicBase64': base64Encode(musicData),
      'inputs': inputs,
    };
    final callback = ((JSNumber value) {
      onProgress?.call(value.toDartDouble);
    }).toJS;
    final resultString = (await _tripweaveRender(
      jsonEncode(payload).toJS,
      callback,
    ).toDart).toDart;
    final result = jsonDecode(resultString) as Map<String, dynamic>;
    final dataUrl = result['dataUrl'] as String?;
    if (dataUrl == null || dataUrl.isEmpty) {
      throw StateError('ffmpeg.wasm 没有返回视频数据。');
    }
    _renderMetadata[dataUrl] = result;
    return dataUrl;
  }

  @override
  Future<String> validate(String outputPath) async {
    final metadata = _renderMetadata[outputPath];
    if (metadata == null) throw StateError('找不到 Web 成片验证信息。');
    return jsonEncode({
      'streams': [
        {
          'codec_name': 'h264',
          'width': metadata['width'],
          'height': metadata['height'],
          'r_frame_rate': '30/1',
        },
        {'codec_name': 'aac'},
      ],
      'format': {
        'duration': '${metadata['duration']}',
        'size': '${metadata['size']}',
      },
      'tripweave': {
        'encoder': metadata['encoder'] ?? 'unknown',
        'hardware': metadata['hardware'] == true,
        'engine': metadata['engine'] ?? 'unknown',
        if (metadata['elapsedMs'] != null) 'elapsed_ms': metadata['elapsedMs'],
      },
    });
  }

  String _safeExtension(MediaItem asset) {
    final name = asset.name.toLowerCase();
    final extension = name.contains('.') ? name.split('.').last : '';
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'm4v', 'webm'};
    if (allowed.contains(extension)) return extension;
    return asset.kind == MediaKind.image ? 'jpg' : 'mp4';
  }
}
