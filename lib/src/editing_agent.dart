import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'editing_agent_models.dart';
import 'models.dart';
import 'music_catalog.dart';
import 'render_backend.dart';

typedef AgentEventSink = void Function(AgentEvent event);

class EditingAgent {
  const EditingAgent({this.client});

  final http.Client? client;

  Future<List<AgentTemplateProposal>> proposeTemplates({
    required VisionLlmConfig config,
    required List<MediaItem> assets,
    required AgentEventSink onEvent,
    String userBrief = '',
  }) async {
    if (!config.isReady) throw StateError('剪辑服务配置不完整。');
    await MusicCatalog.refresh();
    final selected = assets.where((asset) => asset.selected).toList();
    if (selected.length < 2) throw StateError('至少需要两个已选择素材。');

    onEvent(_event(AgentEventKind.thought, '正在建立素材索引并生成视觉联系表。'));
    final previewBytes = <Uint8List>[];
    final renderBackend = createRenderBackend();
    for (final asset in selected.take(9)) {
      if (asset.kind == MediaKind.image) {
        previewBytes.add(asset.displayBytes);
      } else {
        try {
          final frame = await renderBackend.extractVideoFrame(asset);
          if (frame != null) previewBytes.add(frame);
        } catch (_) {
          // Metadata remains available if a platform cannot decode this video.
        }
      }
    }
    final contactSheet = previewBytes.isEmpty
        ? null
        : await compute(_makeContactSheet, previewBytes);
    final metadata = _assetMetadata(selected);

    var visualSummary = '当前平台没有生成可用的视觉联系表，请仅根据素材元数据规划。';
    if (contactSheet != null) {
      onEvent(
        _event(
          AgentEventKind.action,
          '调用视觉模型 ${config.effectiveVisionModel} 理解素材',
        ),
      );
      visualSummary = await _analyzeVisualContactSheet(
        config: config,
        contactSheet: contactSheet,
        metadata: metadata,
      );
      onEvent(
        _event(
          AgentEventKind.observation,
          '视觉模型完成素材观察：${_abbreviate(visualSummary, 220)}',
        ),
      );
    }

    final userContent =
        '这是一次批量导入的旅行素材。视觉模型已经先完成观察，请基于视觉摘要和素材清单，先检查素材，再给出恰好 3 个差异明显、可以直接执行的剪辑模板。'
        '素材清单：${jsonEncode(metadata)}。'
        '视觉摘要：$visualSummary。'
        '可选 CC0 音乐：${jsonEncode([
          for (final track in MusicCatalog.tracks) {'id': track.id, 'title': track.title, 'mood': track.mood},
        ])}。'
        '用户剪辑意图：${userBrief.trim().isEmpty ? '未指定，请根据素材判断' : userBrief.trim()}';
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            '你是 TripWeave 内置剪辑规划 Agent。视觉模型已经提供素材观察结果，你只能通过提供的工具工作。先调用 inspect_assets，再调用 propose_templates。不得引用清单之外的 mediaId 或音乐 id。每个模板必须包含全部或大部分优质素材，单片段 1200 到 8000 毫秒。三个模板应在节奏、画幅、音乐和叙事上明显不同。所有会展示给用户的字段，包括模板名、标题、说明、剪辑理由、标签和字幕，必须只使用自然的简体中文，不得使用英文模板名或英文说明；歌曲原名和内部 id 除外。不要输出思维链。',
      },
      {'role': 'user', 'content': userContent},
    ];

    for (var iteration = 0; iteration < 5; iteration++) {
      final response = await _chat(
        config: config,
        model: config.planningModel,
        messages: messages,
        tools: _planningTools(),
      );
      final message = response['message'] as Map<String, dynamic>;
      final toolCalls = message['tool_calls'] as List<dynamic>?;
      if (toolCalls == null || toolCalls.isEmpty) {
        messages.add(message);
        messages.add({'role': 'user', 'content': '请继续使用工具完成任务，不要只输出文字。'});
        continue;
      }
      messages.add(message);
      for (final rawCall in toolCalls) {
        final call = rawCall as Map<String, dynamic>;
        final function = call['function'] as Map<String, dynamic>;
        final name = function['name'] as String;
        final args = _decodeArguments(function['arguments']);
        onEvent(_event(AgentEventKind.action, _actionLabel(name)));

        if (name == 'inspect_assets') {
          final observation = jsonEncode({
            'assetCount': selected.length,
            'images': selected.where((a) => a.kind == MediaKind.image).length,
            'videos': selected.where((a) => a.kind == MediaKind.video).length,
            'assets': metadata,
            'visualContactSheetIncluded': contactSheet != null,
            'visualSummary': visualSummary,
          });
          onEvent(
            _event(
              AgentEventKind.observation,
              '已读取 ${selected.length} 个素材的类型、比例、文件大小与视觉联系表。',
            ),
          );
          messages.add(_toolObservation(call, observation));
          continue;
        }

        if (name == 'propose_templates') {
          try {
            final templates = _parseTemplates(args, selected);
            onEvent(_event(AgentEventKind.completed, '已生成 3 个剪辑模板，等待用户选择。'));
            return templates;
          } catch (exception) {
            final observation = '模板参数没有通过校验：$exception';
            onEvent(_event(AgentEventKind.observation, observation));
            messages.add(_toolObservation(call, observation));
          }
        }
      }
    }

    onEvent(
      _event(AgentEventKind.observation, '模型没有在循环上限内给出有效工具参数，已切换到本地安全模板。'),
    );
    return _fallbackTemplates(selected);
  }

  Future<AgentRunResult> renderTemplate({
    required AgentTemplateProposal template,
    required List<MediaItem> assets,
    Uint8List? musicBytes,
    required AgentEventSink onEvent,
    void Function(double progress)? onProgress,
  }) async {
    final backend = createRenderBackend();
    final unavailable = await backend.availability();
    if (unavailable != null) throw StateError(unavailable);

    var plan = template.plan;
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      onEvent(_event(AgentEventKind.action, '执行 FFmpeg 渲染 · 第 $attempt 次'));
      try {
        final path = await backend.render(
          plan: plan,
          assets: assets,
          musicBytes: musicBytes,
          onProgress: onProgress,
        );
        onEvent(
          _event(
            AgentEventKind.observation,
            'FFmpeg 已输出候选成片，开始用 FFprobe 检查编码、尺寸和时长。',
          ),
        );
        final validation = await backend.validate(path);
        final validationJson = jsonDecode(validation) as Map<String, dynamic>;
        final format = validationJson['format'] as Map<String, dynamic>?;
        final renderMetadata =
            validationJson['tripweave'] as Map<String, dynamic>?;
        final encoder = '${renderMetadata?['encoder'] ?? 'unknown'}';
        final usedHardware = renderMetadata?['hardware'] == true;
        final duration = double.tryParse('${format?['duration']}') ?? 0;
        final size = int.tryParse('${format?['size']}') ?? 0;
        if (duration <= 0 || size <= 0) {
          throw StateError('FFprobe 没有检测到有效时长或文件大小。');
        }
        onEvent(
          _event(
            AgentEventKind.completed,
            '成片验证通过：${duration.toStringAsFixed(1)} 秒，${(size / 1024 / 1024).toStringAsFixed(1)} MB；'
            '${usedHardware ? '硬件编码' : '兼容编码'} $encoder。',
          ),
        );
        return AgentRunResult(
          plan: plan,
          summary: '已按“${template.name}”模板完成渲染并通过 FFprobe 验证。',
          renderedPath: path,
          validation: validation,
        );
      } catch (exception) {
        lastError = exception;
        onEvent(_event(AgentEventKind.observation, '渲染观察到问题：$exception'));
        plan = _conservativeRevision(plan);
      }
    }
    throw StateError('两次视频生成均未通过检查：$lastError');
  }

  Future<String> _analyzeVisualContactSheet({
    required VisionLlmConfig config,
    required Uint8List contactSheet,
    required List<Map<String, Object?>> metadata,
  }) async {
    final response = await _chat(
      config: config,
      model: config.effectiveVisionModel,
      messages: [
        {
          'role': 'system',
          'content':
              '你是旅行视频素材观察员。只使用简体中文描述联系表中实际可见的主体、场景、动作、光线、氛围、画面质量和可能的叙事顺序。除文件名外不得输出英文句子。不要制定最终剪辑模板，不要声称看到联系表以外的内容。',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  '请逐格观察这批旅行素材的代表帧，并给出供后续剪辑 Agent 使用的中文视觉摘要。素材元数据：${jsonEncode(metadata)}',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${base64Encode(contactSheet)}',
              },
            },
          ],
        },
      ],
      maxTokens: 1600,
    );
    final message = response['message'] as Map<String, dynamic>;
    final content = _messageText(message['content']).trim();
    if (content.isEmpty) throw StateError('视觉模型没有返回素材摘要。');
    return _hasChinese(content)
        ? content
        : '视觉模型已完成主体、场景、光线与画面节奏检查，后续将结合素材顺序生成中文剪辑方案。';
  }

  Future<Map<String, dynamic>> _chat({
    required VisionLlmConfig config,
    required String model,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
    int? maxTokens,
  }) async {
    final body = <String, dynamic>{
      'model': model.trim(),
      'temperature': .25,
      'messages': messages,
      if (tools.isNotEmpty) ...{'tools': tools, 'tool_choice': 'auto'},
      'max_tokens': ?maxTokens,
    };
    final upstreamUri = _chatCompletionsUri(config.endpoint);
    final proxyEndpoint = config.proxyEndpoint.trim();
    final requestUri = proxyEndpoint.isEmpty
        ? upstreamUri
        : Uri.parse(proxyEndpoint);
    final requestBody = proxyEndpoint.isEmpty
        ? body
        : <String, dynamic>{
            'endpoint': upstreamUri.toString(),
            'payload': body,
          };
    final request =
        client?.post(
          requestUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey.trim()}',
          },
          body: jsonEncode(requestBody),
        ) ??
        http.post(
          requestUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey.trim()}',
          },
          body: jsonEncode(requestBody),
        );
    final response = await request.timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        '模型 $model 返回 ${response.statusCode}：${_abbreviate(response.body, 600)}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = payload['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('视觉 LLM 没有返回 choices。');
    }
    return choices.first as Map<String, dynamic>;
  }
}

String _messageText(dynamic content) {
  if (content is String) return content;
  if (content is List) {
    return content
        .whereType<Map>()
        .map((part) => '${part['text'] ?? ''}')
        .where((text) => text.isNotEmpty)
        .join('\n');
  }
  return '';
}

String _abbreviate(String value, int maxLength) {
  final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return clean.length <= maxLength
      ? clean
      : '${clean.substring(0, maxLength)}…';
}

bool _hasChinese(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);

String _chineseField(dynamic value, String fallback) {
  final text = '${value ?? ''}'.trim();
  return text.isNotEmpty && _hasChinese(text) ? text : fallback;
}

Uri _chatCompletionsUri(String endpoint) {
  final uri = Uri.parse(endpoint.trim());
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  if (path.endsWith('/chat/completions')) {
    return uri.replace(path: path);
  }
  if (path.endsWith('/v1')) {
    return uri.replace(path: '$path/chat/completions');
  }
  return uri;
}

Map<String, dynamic> _decodeArguments(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is String && value.trim().isNotEmpty) {
    return jsonDecode(value) as Map<String, dynamic>;
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _toolObservation(
  Map<String, dynamic> call,
  String observation,
) => {'role': 'tool', 'tool_call_id': call['id'], 'content': observation};

String _actionLabel(String name) => switch (name) {
  'inspect_assets' => '调用素材检查工具',
  'propose_templates' => '生成三个结构化剪辑模板',
  _ => '调用工具 $name',
};

AgentEvent _event(AgentEventKind kind, String message) =>
    AgentEvent(kind: kind, message: message, createdAt: DateTime.now());

List<Map<String, Object?>> _assetMetadata(List<MediaItem> assets) => [
  for (final asset in assets)
    {
      'id': asset.id,
      'name': asset.name,
      'kind': asset.kind.name,
      'width': asset.width,
      'height': asset.height,
      'aspectRatio': asset.aspectRatio.toStringAsFixed(3),
      'bytes': asset.byteLength,
      'beautyPreset': asset.isEnhanced ? asset.beautyPreset.name : null,
    },
];

List<AgentTemplateProposal> _parseTemplates(
  Map<String, dynamic> args,
  List<MediaItem> assets,
) {
  final rawTemplates = args['templates'] as List<dynamic>?;
  if (rawTemplates == null || rawTemplates.length != 3) {
    throw const FormatException('必须返回恰好 3 个模板。');
  }
  final validIds = assets.map((asset) => asset.id).toSet();
  final templates = <AgentTemplateProposal>[];
  for (var index = 0; index < rawTemplates.length; index++) {
    final raw = rawTemplates[index] as Map<String, dynamic>;
    final rawClips = raw['clips'] as List<dynamic>?;
    if (rawClips == null || rawClips.length < 2) {
      throw const FormatException('每个模板至少需要 2 个片段。');
    }
    final clips = <AgentClipPlan>[];
    final usedIds = <String>{};
    for (final rawClip in rawClips.take(30)) {
      final clip = rawClip as Map<String, dynamic>;
      final mediaId = '${clip['mediaId']}';
      if (!validIds.contains(mediaId) || !usedIds.add(mediaId)) continue;
      final duration = (clip['durationMs'] as num?)?.round() ?? 2800;
      clips.add(
        AgentClipPlan(
          mediaId: mediaId,
          startMs: ((clip['startMs'] as num?)?.round() ?? 0).clamp(0, 60000),
          durationMs: duration.clamp(1200, 8000),
          caption: _chineseField(clip['caption'], '旅途片段 ${clips.length + 1}'),
        ),
      );
    }
    if (clips.length < 2) throw const FormatException('模板有效片段不足。');
    final ratioName = '${raw['ratio'] ?? 'portrait'}';
    final matchingRatios = VlogRatio.values.where(
      (value) => value.name == ratioName,
    );
    final ratio = matchingRatios.isEmpty
        ? VlogRatio.portrait
        : matchingRatios.first;
    templates.add(
      AgentTemplateProposal(
        id: '${raw['id'] ?? 'template-${index + 1}'}',
        name: _chineseField(raw['name'], ['晴日明信片', '远方电影', '步履手帐'][index]),
        description: _chineseField(
          raw['description'],
          [
            '轻快明亮，适合分享旅途中的人物与风景。',
            '舒缓留白，强调空间、光线和抵达感。',
            '紧凑自然，像一本翻动的旅行手帐。',
          ][index],
        ),
        rationale: _chineseField(
          raw['rationale'] ?? raw['description'],
          '根据素材内容、画面质量与时间顺序自动编排。',
        ),
        accent: _chineseField(raw['accent'], ['轻快', '电影', '手帐'][index]),
        plan: AgentEditPlan(
          title: _chineseField(raw['title'] ?? raw['name'], '旅行记录'),
          style: '${raw['style'] ?? 'travel'}',
          ratio: ratio,
          musicId:
              MusicCatalog.tracks.any(
                (track) => track.id == '${raw['musicId']}',
              )
              ? '${raw['musicId']}'
              : MusicCatalog.tracks[index].id,
          clips: clips,
        ),
      ),
    );
  }
  return templates;
}

List<AgentTemplateProposal> _fallbackTemplates(List<MediaItem> assets) {
  List<AgentClipPlan> clips(double seconds, {bool reverse = false}) {
    final source = reverse ? assets.reversed : assets;
    return [
      for (final asset in source)
        AgentClipPlan(
          mediaId: asset.id,
          durationMs: (seconds * 1000).round(),
          caption: asset.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        ),
    ];
  }

  return [
    AgentTemplateProposal(
      id: 'postcard',
      name: '晴日明信片',
      description: '轻快、明亮，适合竖屏分享和短途旅行。',
      rationale: '按导入顺序保留旅程推进感，用较短停留和明亮音乐突出出发、路上与抵达。',
      accent: '轻快',
      plan: AgentEditPlan(
        title: '这一路，刚刚好',
        style: 'postcard',
        ratio: VlogRatio.portrait,
        musicId: 'elevate-inspirate',
        clips: clips(2.6),
      ),
    ),
    AgentTemplateProposal(
      id: 'cinema',
      name: '远方电影',
      description: '更长的停留与横屏构图，强调空间和抵达感。',
      rationale: '让风景片段停留更久，并使用舒缓音乐连接环境原声，形成电影化的空间感。',
      accent: '电影',
      plan: AgentEditPlan(
        title: '抵达远方以前',
        style: 'cinema',
        ratio: VlogRatio.landscape,
        musicId: 'eye-of-forgiveness',
        clips: clips(3.8),
      ),
    ),
    AgentTemplateProposal(
      id: 'journal',
      name: '步履手帐',
      description: '紧凑片段和方形画幅，像一本快速翻动的旅行手帐。',
      rationale: '用紧凑节奏快速回看素材，强调人物和细节，适合社交平台的轻量记录。',
      accent: '手帐',
      plan: AgentEditPlan(
        title: '一路拾光',
        style: 'journal',
        ratio: VlogRatio.square,
        musicId: 'city-run',
        clips: clips(2.2, reverse: true),
      ),
    ),
  ];
}

AgentEditPlan _conservativeRevision(AgentEditPlan plan) => AgentEditPlan(
  title: plan.title,
  style: '${plan.style}-safe',
  ratio: plan.ratio,
  musicId: plan.musicId,
  clips: [
    for (final clip in plan.clips)
      AgentClipPlan(
        mediaId: clip.mediaId,
        startMs: clip.startMs,
        durationMs: clip.durationMs.clamp(1800, 5000),
        caption: clip.caption,
      ),
  ],
);

Uint8List _makeContactSheet(List<Uint8List> inputs) {
  const cellWidth = 256;
  const cellHeight = 160;
  const columns = 3;
  final rows = (inputs.length / columns).ceil();
  final sheet = img.Image(
    width: cellWidth * columns,
    height: cellHeight * rows,
  );
  img.fill(sheet, color: img.ColorRgb8(28, 30, 28));
  for (var index = 0; index < inputs.length; index++) {
    final decoded = img.decodeImage(inputs[index]);
    if (decoded == null) continue;
    final sourceAspect = decoded.width / decoded.height;
    const targetAspect = cellWidth / cellHeight;
    late img.Image crop;
    if (sourceAspect > targetAspect) {
      final cropWidth = (decoded.height * targetAspect).round();
      crop = img.copyCrop(
        decoded,
        x: ((decoded.width - cropWidth) / 2).round(),
        y: 0,
        width: cropWidth,
        height: decoded.height,
      );
    } else {
      final cropHeight = (decoded.width / targetAspect).round();
      crop = img.copyCrop(
        decoded,
        x: 0,
        y: ((decoded.height - cropHeight) / 2).round(),
        width: decoded.width,
        height: cropHeight,
      );
    }
    final thumb = img.copyResize(crop, width: cellWidth, height: cellHeight);
    img.compositeImage(
      sheet,
      thumb,
      dstX: (index % columns) * cellWidth,
      dstY: (index ~/ columns) * cellHeight,
      blend: img.BlendMode.direct,
    );
  }
  return Uint8List.fromList(img.encodeJpg(sheet, quality: 82));
}

List<Map<String, dynamic>> _planningTools() => <Map<String, dynamic>>[
  {
    'type': 'function',
    'function': {
      'name': 'inspect_assets',
      'description': '读取批量素材清单和视觉联系表，确认可用素材。',
      'parameters': {
        'type': 'object',
        'properties': <String, Object>{},
        'additionalProperties': false,
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'propose_templates',
      'description': '提交恰好三个供用户选择的结构化剪辑模板。',
      'parameters': {
        'type': 'object',
        'required': ['templates'],
        'properties': {
          'templates': {
            'type': 'array',
            'minItems': 3,
            'maxItems': 3,
            'items': {
              'type': 'object',
              'required': [
                'id',
                'name',
                'description',
                'rationale',
                'accent',
                'title',
                'style',
                'ratio',
                'musicId',
                'clips',
              ],
              'properties': {
                'id': {'type': 'string'},
                'name': {'type': 'string'},
                'description': {'type': 'string'},
                'rationale': {'type': 'string'},
                'accent': {'type': 'string'},
                'title': {'type': 'string'},
                'style': {'type': 'string'},
                'ratio': {
                  'type': 'string',
                  'enum': ['portrait', 'landscape', 'square'],
                },
                'musicId': {
                  'type': 'string',
                  'enum': [for (final track in MusicCatalog.tracks) track.id],
                },
                'clips': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'required': ['mediaId', 'startMs', 'durationMs', 'caption'],
                    'properties': {
                      'mediaId': {'type': 'string'},
                      'startMs': {'type': 'integer'},
                      'durationMs': {'type': 'integer'},
                      'caption': {'type': 'string'},
                    },
                  },
                },
              },
            },
          },
        },
        'additionalProperties': false,
      },
    },
  },
];
