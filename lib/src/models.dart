import 'dart:typed_data';

enum MediaKind { image, video }

enum ProcessingStatus { original, queued, processing, enhanced, failed }

enum BeautyPreset { natural, smooth, bright, slim }

enum VlogStyle { postcard, cinema, journal }

enum VlogRatio { portrait, landscape, square }

class MediaItem {
  MediaItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.bytes,
    required this.importedAt,
    required this.byteLength,
    this.sourcePath,
    this.width,
    this.height,
  });

  final String id;
  final String name;
  final MediaKind kind;
  final Uint8List bytes;
  final DateTime importedAt;
  final int byteLength;
  final String? sourcePath;
  final int? width;
  final int? height;

  Uint8List? enhancedBytes;
  ProcessingStatus status = ProcessingStatus.original;
  double beautyLevel = .62;
  BeautyPreset beautyPreset = BeautyPreset.natural;
  bool selected = true;

  Uint8List get displayBytes => enhancedBytes ?? bytes;
  bool get hasLocalSource => sourcePath?.trim().isNotEmpty == true;
  bool get isEnhanced =>
      enhancedBytes != null || status == ProcessingStatus.enhanced;

  double get aspectRatio {
    if (width == null || height == null || height == 0) return 4 / 3;
    return width! / height!;
  }

  String get sizeLabel {
    if (byteLength < 1024 * 1024) {
      return '${(byteLength / 1024).toStringAsFixed(0)} KB';
    }
    return '${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class VlogClip {
  const VlogClip({
    required this.mediaId,
    required this.duration,
    required this.caption,
    required this.transition,
  });

  final String mediaId;
  final Duration duration;
  final String caption;
  final String transition;
}

class VlogDraft {
  const VlogDraft({
    required this.title,
    required this.subtitle,
    required this.style,
    required this.ratio,
    required this.music,
    required this.clips,
    required this.createdAt,
  });

  final String title;
  final String subtitle;
  final VlogStyle style;
  final VlogRatio ratio;
  final String music;
  final List<VlogClip> clips;
  final DateTime createdAt;

  Duration get totalDuration =>
      clips.fold(Duration.zero, (total, clip) => total + clip.duration);

  Map<String, Object> toJson() => {
    'format': 'tripweave-v1',
    'title': title,
    'subtitle': subtitle,
    'style': style.name,
    'ratio': ratio.name,
    'music': music,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': totalDuration.inMilliseconds,
    'clips': clips
        .map(
          (clip) => {
            'mediaId': clip.mediaId,
            'durationMs': clip.duration.inMilliseconds,
            'caption': clip.caption,
            'transition': clip.transition,
          },
        )
        .toList(),
  };
}

class VisionLlmConfig {
  const VisionLlmConfig({
    this.enabled = false,
    this.endpoint = '',
    this.proxyEndpoint = '',
    this.planningModel = '',
    this.visionModel = '',
    this.apiKey = '',
  });

  final bool enabled;
  final String endpoint;
  final String proxyEndpoint;
  final String planningModel;
  final String visionModel;
  final String apiKey;

  String get effectiveVisionModel =>
      visionModel.trim().isEmpty ? planningModel.trim() : visionModel.trim();

  bool get isReady =>
      enabled &&
      endpoint.trim().isNotEmpty &&
      planningModel.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;
}
