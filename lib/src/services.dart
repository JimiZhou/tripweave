import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'models.dart';

class DecodedImageInfo {
  const DecodedImageInfo(this.width, this.height);
  final int width;
  final int height;
}

class BeautyService {
  static Future<DecodedImageInfo?> inspect(Uint8List bytes) async {
    return compute(_inspectImage, bytes);
  }

  static Future<Uint8List> enhance(
    Uint8List bytes,
    double level,
    BeautyPreset preset,
  ) async {
    return compute(_enhanceImage, <String, Object>{
      'bytes': bytes,
      'level': level,
      'preset': preset.name,
    });
  }
}

DecodedImageInfo? _inspectImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return DecodedImageInfo(decoded.width, decoded.height);
}

Uint8List _enhanceImage(Map<String, Object> request) {
  final bytes = request['bytes']! as Uint8List;
  final level = (request['level']! as double).clamp(0.0, 1.0);
  final preset = BeautyPreset.values.byName(request['preset']! as String);
  var source = img.decodeImage(bytes);
  if (source == null) return bytes;

  if (math.max(source.width, source.height) > 2400) {
    source = source.width >= source.height
        ? img.copyResize(source, width: 2400)
        : img.copyResize(source, height: 2400);
  }

  final smoothBoost = switch (preset) {
    BeautyPreset.smooth => .18,
    BeautyPreset.natural => .04,
    BeautyPreset.bright => .02,
    BeautyPreset.slim => .06,
  };
  final softened = img.gaussianBlur(
    source.clone(),
    radius: preset == BeautyPreset.smooth && level > .55
        ? 4
        : level > .72
        ? 3
        : 2,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final blur = softened.getPixel(x, y);
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final maxChannel = math.max(r, math.max(g, b));
      final minChannel = math.min(r, math.min(g, b));
      final skin =
          r > 78 &&
          g > 32 &&
          b > 18 &&
          r > g &&
          r > b &&
          maxChannel - minChannel > 12 &&
          (r - g).abs() > 8;

      if (skin) {
        final blend = (.08 + smoothBoost + level * .30).clamp(0.0, .58);
        p
          ..r = (r * (1 - blend) + blur.r * blend + level * 2.4).clamp(0, 255)
          ..g = (g * (1 - blend) + blur.g * blend + level * 1.2).clamp(0, 255)
          ..b = (b * (1 - blend) + blur.b * blend - level * .8).clamp(0, 255);
      }
    }
  }

  if (preset == BeautyPreset.slim) {
    source = _applyConservativeSlim(source, level);
  }

  source = img.adjustColor(
    source,
    brightness:
        1 +
        level *
            switch (preset) {
              BeautyPreset.bright => .075,
              BeautyPreset.natural => .035,
              BeautyPreset.smooth => .025,
              BeautyPreset.slim => .03,
            },
    contrast: 1 + level * (preset == BeautyPreset.bright ? .07 : .05),
    saturation: 1 + level * (preset == BeautyPreset.bright ? .085 : .05),
    gamma: 1 - level * (preset == BeautyPreset.bright ? .045 : .022),
  );
  return Uint8List.fromList(img.encodeJpg(source, quality: 92));
}

img.Image _applyConservativeSlim(img.Image source, double level) {
  final original = source.clone();
  final centerX = source.width / 2;
  final halfSpan = source.width * .33;
  final strength = .055 * level;
  final startY = (source.height * .28).round();
  final endY = (source.height * .88).round();

  for (var y = startY; y < endY; y++) {
    final normalizedY = y / source.height;
    final verticalEnvelope = math.exp(-math.pow((normalizedY - .58) / .23, 2));
    for (
      var x = (centerX - halfSpan).round();
      x < (centerX + halfSpan).round();
      x++
    ) {
      final dx = (x - centerX) / halfSpan;
      final edgeEnvelope = math.pow(1 - dx.abs(), 2);
      final sourceX =
          centerX +
          (x - centerX) * (1 + strength * verticalEnvelope * edgeEnvelope);
      final sample = original.getPixel(
        sourceX.round().clamp(0, original.width - 1),
        y,
      );
      source.setPixel(x, y, sample);
    }
  }
  return source;
}

class VlogService {
  static VlogDraft generate({
    required List<MediaItem> assets,
    required String title,
    required VlogStyle style,
    required VlogRatio ratio,
  }) {
    final chosen = assets.where((asset) => asset.selected).toList()
      ..sort((a, b) => a.importedAt.compareTo(b.importedAt));
    const transitions = ['胶片叠化', '地图推镜', '日光闪白', '纸页翻转'];

    final clips = <VlogClip>[];
    for (var i = 0; i < chosen.length; i++) {
      final asset = chosen[i];
      final basename = asset.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      clips.add(
        VlogClip(
          mediaId: asset.id,
          duration: Duration(
            milliseconds: asset.kind == MediaKind.image ? 2800 : 4800,
          ),
          caption: _captionFor(basename, i),
          transition: transitions[i % transitions.length],
        ),
      );
    }

    return VlogDraft(
      title: title.trim().isEmpty ? '这一路，刚刚好' : title.trim(),
      subtitle: '${chosen.length} 个片段 · 一段正在发光的旅程',
      style: style,
      ratio: ratio,
      music: switch (style) {
        VlogStyle.postcard => '橘色公路 · 轻快原声',
        VlogStyle.cinema => '远方来信 · 电影氛围',
        VlogStyle.journal => '步履之间 · 手帐节拍',
      },
      clips: clips,
      createdAt: DateTime.now(),
    );
  }

  static String encodeProject(VlogDraft draft, List<MediaItem> assets) {
    final media = assets
        .where((asset) => draft.clips.any((clip) => clip.mediaId == asset.id))
        .map(
          (asset) => {
            'id': asset.id,
            'name': asset.name,
            'kind': asset.kind.name,
            'enhanced': asset.isEnhanced,
            'beautyPreset': asset.isEnhanced ? asset.beautyPreset.name : null,
            'beautyLevel': asset.isEnhanced ? asset.beautyLevel : null,
            'renderPath': asset.isEnhanced ? 'gpu-runtime-shader' : 'original',
            'bytes': asset.byteLength,
          },
        )
        .toList();
    return const JsonEncoder.withIndent(
      '  ',
    ).convert({...draft.toJson(), 'media': media});
  }

  static String _captionFor(String name, int index) {
    final clean = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (clean.isNotEmpty &&
        !RegExp(
          r'^(img|dsc|video|vid)\s*\d*$',
          caseSensitive: false,
        ).hasMatch(clean)) {
      return clean;
    }
    const fallbacks = ['出发，是故事最轻的一笔', '风景在路上慢慢展开', '把这一刻留给未来', '抵达，也是一种新的开始'];
    return fallbacks[index % fallbacks.length];
  }
}
