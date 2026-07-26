import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// A named, admin-managed model configuration that regular users can apply
/// with one tap and without ever seeing the API key.
class ModelPreset {
  const ModelPreset({
    required this.id,
    required this.name,
    required this.endpoint,
    this.proxyEndpoint = '',
    required this.planningModel,
    this.visionModel = '',
    required this.apiKey,
    this.note = '',
    this.builtIn = false,
  });

  final String id;
  final String name;
  final String endpoint;
  final String proxyEndpoint;
  final String planningModel;
  final String visionModel;
  final String apiKey;
  final String note;

  /// Built-in presets ship with the deployment via `--dart-define` and cannot
  /// be edited or deleted from the device admin panel.
  final bool builtIn;

  VisionLlmConfig toConfig() => VisionLlmConfig(
    enabled: true,
    endpoint: endpoint,
    proxyEndpoint: proxyEndpoint,
    planningModel: planningModel,
    visionModel: visionModel,
    apiKey: apiKey,
  );

  factory ModelPreset.fromJson(
    Map<String, dynamic> json, {
    bool builtIn = false,
  }) => ModelPreset(
    id: '${json['id'] ?? json['name'] ?? ''}',
    name: '${json['name'] ?? ''}',
    endpoint: '${json['endpoint'] ?? ''}',
    proxyEndpoint: '${json['proxyEndpoint'] ?? ''}',
    planningModel: '${json['planningModel'] ?? ''}',
    visionModel: '${json['visionModel'] ?? ''}',
    apiKey: '${json['apiKey'] ?? ''}',
    note: '${json['note'] ?? ''}',
    builtIn: builtIn,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'endpoint': endpoint,
    'proxyEndpoint': proxyEndpoint,
    'planningModel': planningModel,
    'visionModel': visionModel,
    'apiKey': apiKey,
    'note': note,
  };

  bool get isUsable =>
      endpoint.trim().isNotEmpty &&
      planningModel.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;
}

class ModelPresetStore {
  static const _presetsKey = 'tripweave.model-presets.v1';
  static const _defaultKey = 'tripweave.model-presets.default.v1';

  /// Deployment-provided presets, e.g. for a self-hosted web build:
  /// `TRIPWEAVE_MODEL_PRESETS='[{"id":"studio","name":"工作室通道",...}]'`.
  /// Web builds embed the value in downloadable JavaScript, so only use it
  /// for private deployments behind access control.
  static const presetDefine = String.fromEnvironment(
    'TRIPWEAVE_MODEL_PRESETS',
  );

  static List<ModelPreset> builtInPresets() {
    if (presetDefine.trim().isEmpty) return const [];
    try {
      return (jsonDecode(presetDefine) as List)
          .whereType<Map>()
          .map(
            (item) => ModelPreset.fromJson(
              item.cast<String, dynamic>(),
              builtIn: true,
            ),
          )
          .where((preset) => preset.id.isNotEmpty && preset.isUsable)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ModelPreset>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final builtIn = builtInPresets();
    final encoded = preferences.getString(_presetsKey);
    if (encoded == null || encoded.isEmpty) return [...builtIn];
    try {
      final local = (jsonDecode(encoded) as List)
          .whereType<Map>()
          .map((item) => ModelPreset.fromJson(item.cast<String, dynamic>()))
          .toList();
      final localIds = local.map((preset) => preset.id).toSet();
      return [
        ...builtIn.where((preset) => !localIds.contains(preset.id)),
        ...local,
      ];
    } catch (_) {
      return [...builtIn];
    }
  }

  Future<void> save(List<ModelPreset> presets) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _presetsKey,
      jsonEncode(
        presets
            .where((preset) => !preset.builtIn)
            .map((preset) => preset.toJson())
            .toList(),
      ),
    );
  }

  Future<String?> loadDefaultId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_defaultKey);
  }

  Future<void> saveDefaultId(String? id) async {
    final preferences = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await preferences.remove(_defaultKey);
    } else {
      await preferences.setString(_defaultKey, id);
    }
  }
}
