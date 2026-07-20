import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/src/editing_agent.dart';
import 'package:tripweave/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final runRealE2e = Platform.environment['TW_RUN_REAL_E2E'] == '1';
  test(
    'real API analyzes downloaded videos and renders a validated vlog',
    () async {
      // Flutter's test binding installs an HttpOverrides implementation that
      // returns HTTP 400 for every request. This opt-in smoke test deliberately
      // restores the real system client because its purpose is live E2E proof.
      HttpOverrides.global = null;
      final endpoint = _requiredEnvironment('TW_ENDPOINT');
      final apiKey = _requiredEnvironment('TW_API_KEY');
      final demoDirectory = Directory(_requiredEnvironment('TW_DEMO_DIR'));
      final outputPath = _requiredEnvironment('TW_E2E_OUTPUT');
      final evidencePath = _requiredEnvironment('TW_E2E_EVIDENCE');
      final planningModel = _requiredEnvironment('TW_PLANNING_MODEL');
      final visionModel = _requiredEnvironment('TW_VISION_MODEL');

      final sourceFiles =
          demoDirectory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.webm'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(sourceFiles.length, greaterThanOrEqualTo(3));

      final assets = <MediaItem>[];
      for (var index = 0; index < sourceFiles.length; index++) {
        final file = sourceFiles[index];
        final bytes = await file.readAsBytes();
        assets.add(
          MediaItem(
            id: 'demo-${index + 1}',
            name: file.uri.pathSegments.last,
            kind: MediaKind.video,
            bytes: bytes,
            importedAt: DateTime(2026, 7, 17, 10, index),
            byteLength: bytes.length,
            width: 1920,
            height: index == 0 ? 1280 : 1080,
          ),
        );
      }

      final events = <Map<String, Object?>>[];
      final agent = const EditingAgent();
      final templates = await agent.proposeTemplates(
        config: VisionLlmConfig(
          enabled: true,
          endpoint: endpoint,
          planningModel: planningModel,
          visionModel: visionModel,
          apiKey: apiKey,
        ),
        assets: assets,
        userBrief: '做一条 12 到 18 秒的横屏自然旅行 Vlog，先云海，再湖泊，最后森林与农场。保留少量现场原声。',
        onEvent: (event) {
          events.add({
            'kind': event.kind.name,
            'message': event.message,
            'createdAt': event.createdAt.toIso8601String(),
          });
        },
      );

      expect(templates, hasLength(3));
      expect(
        events.any((event) => '${event['message']}'.contains('视觉模型完成素材观察')),
        isTrue,
      );
      expect(
        events.any((event) => '${event['message']}'.contains('已切换到本地安全模板')),
        isFalse,
      );

      final selected = templates.firstWhere(
        (template) => template.plan.ratio == VlogRatio.landscape,
        orElse: () => templates.first,
      );
      final result = await agent.renderTemplate(
        template: selected,
        assets: assets,
        onEvent: (event) {
          events.add({
            'kind': event.kind.name,
            'message': event.message,
            'createdAt': event.createdAt.toIso8601String(),
          });
        },
      );
      expect(result.renderedPath, isNotNull);
      expect(result.validation, isNotNull);
      final renderedFile = File(result.renderedPath!);
      expect(await renderedFile.exists(), isTrue);
      expect(await renderedFile.length(), greaterThan(10000));
      await renderedFile.copy(outputPath);

      final validation = jsonDecode(result.validation!);
      await File(evidencePath).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'planningModel': planningModel,
          'visionModel': visionModel,
          'sourceFiles': [for (final file in sourceFiles) file.path],
          'templates': [
            for (final template in templates)
              {
                'id': template.id,
                'name': template.name,
                'description': template.description,
                'rationale': template.rationale,
                'ratio': template.plan.ratio.name,
                'musicId': template.plan.musicId,
                'clips': [
                  for (final clip in template.plan.clips)
                    {
                      'mediaId': clip.mediaId,
                      'startMs': clip.startMs,
                      'durationMs': clip.durationMs,
                      'caption': clip.caption,
                    },
                ],
              },
          ],
          'selectedTemplate': selected.id,
          'outputPath': outputPath,
          'validation': validation,
          'events': events,
        }),
      );
    },
    skip: runRealE2e ? false : 'Set TW_RUN_REAL_E2E=1 to call the real API.',
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim() ?? '';
  if (value.isEmpty) throw StateError('Missing environment variable $name');
  return value;
}
