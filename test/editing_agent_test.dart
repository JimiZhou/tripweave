import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:tripweave/src/editing_agent.dart';
import 'package:tripweave/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('editing agent uses vision then planning model ReAct loop', () async {
    final requestedModels = <String>[];
    var requestIndex = 0;
    final client = MockClient((request) async {
      final envelope = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.toString(), 'https://proxy.example.test/llm');
      expect(envelope['endpoint'], 'https://example.test/v1/chat/completions');
      final payload = envelope['payload'] as Map<String, dynamic>;
      requestedModels.add('${payload['model']}');
      requestIndex++;

      if (requestIndex == 1) {
        final content = (payload['messages'] as List).last as Map;
        expect(content['content'], isA<List>());
        return _response({
          'role': 'assistant',
          'content': '山景、湖泊与人物同行画面，光线明亮，适合从远景到人物推进。',
        });
      }
      if (requestIndex == 2) {
        expect(payload['tools'], isA<List>());
        return _response({
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'id': 'inspect-1',
              'type': 'function',
              'function': {'name': 'inspect_assets', 'arguments': '{}'},
            },
          ],
        });
      }
      return _response({
        'role': 'assistant',
        'content': '',
        'tool_calls': [
          {
            'id': 'templates-1',
            'type': 'function',
            'function': {
              'name': 'propose_templates',
              'arguments': jsonEncode({
                'templates': [
                  _template('bright', '明亮出发', 'portrait', 'city-run'),
                  _template(
                    'cinema',
                    '山湖电影',
                    'landscape',
                    'eye-of-forgiveness',
                  ),
                  _template('journal', '同行手帐', 'square', 'elevate-inspirate'),
                ],
              }),
            },
          },
        ],
      });
    });

    final assets = [_asset('a', 210, 130, 80), _asset('b', 70, 130, 190)];
    final events = <String>[];
    final templates = await EditingAgent(client: client).proposeTemplates(
      config: const VisionLlmConfig(
        enabled: true,
        endpoint: 'https://example.test/v1',
        proxyEndpoint: 'https://proxy.example.test/llm',
        planningModel: 'planner-model',
        visionModel: 'vision-model',
        apiKey: 'test-key',
      ),
      assets: assets,
      onEvent: (event) => events.add(event.message),
    );

    expect(requestedModels, ['vision-model', 'planner-model', 'planner-model']);
    expect(templates, hasLength(3));
    expect(templates.first.plan.clips, hasLength(2));
    expect(events.join('\n'), contains('视觉模型完成素材观察'));
    expect(events.join('\n'), contains('已生成 3 个剪辑模板'));
  });

  test('empty vision model reuses multimodal planning model', () {
    const config = VisionLlmConfig(
      enabled: true,
      endpoint: 'https://example.test/v1/chat/completions',
      planningModel: 'multimodal-model',
      apiKey: 'test-key',
    );
    expect(config.isReady, isTrue);
    expect(config.effectiveVisionModel, 'multimodal-model');
  });
}

http.Response _response(Map<String, dynamic> message) => http.Response(
  jsonEncode({
    'choices': [
      {'index': 0, 'message': message, 'finish_reason': 'tool_calls'},
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _template(
  String id,
  String name,
  String ratio,
  String musicId,
) => {
  'id': id,
  'name': name,
  'description': '$name 模板',
  'rationale': '根据视觉摘要安排远景与人物镜头。',
  'accent': name,
  'title': name,
  'style': id,
  'ratio': ratio,
  'musicId': musicId,
  'clips': [
    {'mediaId': 'a', 'startMs': 0, 'durationMs': 1800, 'caption': '出发'},
    {'mediaId': 'b', 'startMs': 200, 'durationMs': 2200, 'caption': '抵达'},
  ],
};

MediaItem _asset(String id, int red, int green, int blue) {
  final image = img.Image(width: 96, height: 64);
  img.fill(image, color: img.ColorRgb8(red, green, blue));
  final bytes = Uint8List.fromList(img.encodeJpg(image));
  return MediaItem(
    id: id,
    name: '$id.jpg',
    kind: MediaKind.image,
    bytes: bytes,
    importedAt: DateTime(2026),
    byteLength: bytes.length,
    width: 96,
    height: 64,
  );
}
