import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'editing_agent_models.dart';
import 'models.dart';

class JourneyAssetRecord {
  const JourneyAssetRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.importedAt,
    required this.byteLength,
    required this.selected,
    required this.status,
    required this.beautyLevel,
    required this.beautyPreset,
    this.sourcePath,
    this.width,
    this.height,
  });

  final String id;
  final String name;
  final MediaKind kind;
  final DateTime importedAt;
  final int byteLength;
  final String? sourcePath;
  final int? width;
  final int? height;
  final bool selected;
  final ProcessingStatus status;
  final double beautyLevel;
  final BeautyPreset beautyPreset;

  factory JourneyAssetRecord.fromMedia(MediaItem asset) => JourneyAssetRecord(
    id: asset.id,
    name: asset.name,
    kind: asset.kind,
    importedAt: asset.importedAt,
    byteLength: asset.byteLength,
    sourcePath: asset.sourcePath,
    width: asset.width,
    height: asset.height,
    selected: asset.selected,
    status: asset.status,
    beautyLevel: asset.beautyLevel,
    beautyPreset: asset.beautyPreset,
  );

  factory JourneyAssetRecord.fromJson(Map<String, dynamic> json) =>
      JourneyAssetRecord(
        id: '${json['id']}',
        name: '${json['name']}',
        kind: MediaKind.values.byName('${json['kind']}'),
        importedAt: DateTime.parse('${json['importedAt']}'),
        byteLength: (json['byteLength'] as num?)?.toInt() ?? 0,
        sourcePath: json['sourcePath'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        selected: json['selected'] != false,
        status: ProcessingStatus.values.byName(
          '${json['status'] ?? ProcessingStatus.original.name}',
        ),
        beautyLevel: (json['beautyLevel'] as num?)?.toDouble() ?? .62,
        beautyPreset: BeautyPreset.values.byName(
          '${json['beautyPreset'] ?? BeautyPreset.natural.name}',
        ),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'importedAt': importedAt.toIso8601String(),
    'byteLength': byteLength,
    'sourcePath': sourcePath,
    'width': width,
    'height': height,
    'selected': selected,
    'status': status.name,
    'beautyLevel': beautyLevel,
    'beautyPreset': beautyPreset.name,
  };
}

class CompletedJourney {
  const CompletedJourney({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.assets,
    required this.templates,
    required this.selectedTemplateId,
    required this.userBrief,
    this.localMusicName,
    this.localMusicPath,
    this.musicTitle,
    this.musicArtist,
    this.musicLicense,
    this.musicSourceUrl,
    this.renderedPath,
    this.validation,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<JourneyAssetRecord> assets;
  final List<AgentTemplateProposal> templates;
  final String selectedTemplateId;
  final String userBrief;
  final String? localMusicName;
  final String? localMusicPath;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicLicense;
  final String? musicSourceUrl;
  final String? renderedPath;
  final String? validation;

  AgentTemplateProposal? get selectedTemplate {
    final selected = templates.where((item) => item.id == selectedTemplateId);
    return selected.isEmpty ? null : selected.first;
  }

  int get durationMs => selectedTemplate?.plan.totalDurationMs ?? 0;

  factory CompletedJourney.fromJson(Map<String, dynamic> json) =>
      CompletedJourney(
        id: '${json['id']}',
        title: '${json['title']}',
        createdAt: DateTime.parse('${json['createdAt']}'),
        updatedAt: DateTime.parse('${json['updatedAt']}'),
        assets: (json['assets'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  JourneyAssetRecord.fromJson(item.cast<String, dynamic>()),
            )
            .toList(),
        templates: (json['templates'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => _templateFromJson(item.cast<String, dynamic>()))
            .toList(),
        selectedTemplateId: '${json['selectedTemplateId']}',
        userBrief: '${json['userBrief'] ?? ''}',
        localMusicName: json['localMusicName'] as String?,
        localMusicPath: json['localMusicPath'] as String?,
        musicTitle: json['musicTitle'] as String?,
        musicArtist: json['musicArtist'] as String?,
        musicLicense: json['musicLicense'] as String?,
        musicSourceUrl: json['musicSourceUrl'] as String?,
        renderedPath: json['renderedPath'] as String?,
        validation: json['validation'] as String?,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'assets': assets.map((item) => item.toJson()).toList(),
    'templates': templates.map(_templateToJson).toList(),
    'selectedTemplateId': selectedTemplateId,
    'userBrief': userBrief,
    'localMusicName': localMusicName,
    'localMusicPath': localMusicPath,
    'musicTitle': musicTitle,
    'musicArtist': musicArtist,
    'musicLicense': musicLicense,
    'musicSourceUrl': musicSourceUrl,
    'renderedPath': renderedPath?.startsWith('data:') == true
        ? null
        : renderedPath,
    'validation': validation,
  };
}

class JourneyHistoryStore {
  static const _key = 'tripweave.completed-journeys.v1';

  Future<List<CompletedJourney>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded) as List;
      return decoded
          .whereType<Map>()
          .map(
            (item) => CompletedJourney.fromJson(item.cast<String, dynamic>()),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<CompletedJourney> journeys) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(journeys.map((item) => item.toJson()).toList()),
    );
  }
}

Map<String, Object> _templateToJson(AgentTemplateProposal template) => {
  'id': template.id,
  'name': template.name,
  'description': template.description,
  'rationale': template.rationale,
  'accent': template.accent,
  'plan': template.plan.toJson(),
};

AgentTemplateProposal _templateFromJson(Map<String, dynamic> json) {
  final plan = (json['plan'] as Map).cast<String, dynamic>();
  final ratio = VlogRatio.values.where(
    (item) => item.name == '${plan['ratio']}',
  );
  return AgentTemplateProposal(
    id: '${json['id']}',
    name: '${json['name']}',
    description: '${json['description']}',
    rationale: '${json['rationale']}',
    accent: '${json['accent']}',
    plan: AgentEditPlan(
      title: '${plan['title']}',
      style: '${plan['style']}',
      ratio: ratio.isEmpty ? VlogRatio.landscape : ratio.first,
      musicId: '${plan['musicId']}',
      clips: (plan['clips'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (clip) => AgentClipPlan(
              mediaId: '${clip['mediaId']}',
              durationMs: (clip['durationMs'] as num?)?.toInt() ?? 2800,
              caption: '${clip['caption'] ?? ''}',
              startMs: (clip['startMs'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
    ),
  );
}
