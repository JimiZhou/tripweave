import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/src/app.dart';
import 'package:tripweave/src/app_state.dart';
import 'package:tripweave/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final runClientE2e = Platform.environment['TW_RUN_CLIENT_E2E'] == '1';
  testWidgets(
    'macOS client imports videos, runs agent, renders and exposes preview UI',
    (tester) async {
      debugPrint('[client-e2e] test body entered');
      HttpOverrides.global = null;
      final endpoint = _requiredEnvironment('TW_ENDPOINT');
      final apiKey = _requiredEnvironment('TW_API_KEY');
      final demoDirectory = Directory(_requiredEnvironment('TW_DEMO_DIR'));
      final outputPath = _requiredEnvironment('TW_CLIENT_E2E_OUTPUT');
      final evidencePath = _requiredEnvironment('TW_CLIENT_E2E_EVIDENCE');
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
      debugPrint('[client-e2e] found ${sourceFiles.length} source files');

      final state = AppState();
      await tester.pumpWidget(TripWeaveApp(state: state));
      debugPrint('[client-e2e] widget pumped');
      await _pumpFrames(tester);
      debugPrint('[client-e2e] initial frames pumped');
      expect(find.text('导入照片与视频'), findsOneWidget);

      final selectedFiles = await tester.runAsync(() async {
        final files = <XFile>[];
        for (final file in sourceFiles) {
          files.add(
            XFile.fromData(
              await file.readAsBytes(),
              name: file.uri.pathSegments.last,
              mimeType: 'video/webm',
            ),
          );
        }
        return files;
      });
      expect(selectedFiles, isNotNull);
      final importedFiles = selectedFiles!;
      debugPrint(
        '[client-e2e] prepared ${importedFiles.length} selected files',
      );
      await tester.runAsync(() => state.importMediaFiles(importedFiles));
      await _pumpFrames(tester);
      expect(state.videoCount, sourceFiles.length);
      expect(state.notice, contains('已导入 3 个旅行片段'));
      debugPrint('[client-e2e] imported ${state.videoCount} videos');

      state.setVisionConfig(
        VisionLlmConfig(
          enabled: true,
          endpoint: endpoint,
          planningModel: planningModel,
          visionModel: visionModel,
          apiKey: apiKey,
        ),
      );
      state.setAgentUserBrief('做一条 12 到 18 秒的横屏自然旅行 Vlog，先云海，再湖泊，最后森林与农场。');
      state.goTo(2);
      await _pumpFrames(tester);
      expect(find.text('让剪辑 Agent 读懂旅程'), findsOneWidget);

      debugPrint('[client-e2e] starting configured vision + planning analysis');
      await tester.runAsync(state.analyzeWithEditingAgent);
      await _pumpFrames(tester);
      expect(state.error, isNull);
      expect(state.agentTemplates, hasLength(3));
      expect(find.text('选择一个故事方向'), findsOneWidget);
      debugPrint(
        '[client-e2e] received ${state.agentTemplates.length} templates',
      );

      final landscape = state.agentTemplates.firstWhere(
        (template) => template.plan.ratio == VlogRatio.landscape,
        orElse: () => state.agentTemplates.first,
      );
      state.selectAgentTemplate(landscape.id);
      debugPrint('[client-e2e] rendering template ${landscape.id}');
      await tester.runAsync(state.renderSelectedAgentTemplate);
      await _pumpFrames(tester);

      expect(state.error, isNull);
      expect(state.agentResult?.renderedPath, isNotNull);
      expect(state.agentResult?.validation, isNotNull);
      expect(find.text('保存 MP4'), findsWidgets);
      expect(state.agentResult!.validation, contains('aac'));

      final renderedFile = File(state.agentResult!.renderedPath!);
      await tester.runAsync(() async {
        expect(await renderedFile.exists(), isTrue);
        expect(await renderedFile.length(), greaterThan(10000));
        await renderedFile.copy(outputPath);
        await File(evidencePath).writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'client': 'macOS Flutter widget client',
            'planningModel': planningModel,
            'visionModel': visionModel,
            'sourceFiles': [for (final file in sourceFiles) file.path],
            'importedVideoCount': state.videoCount,
            'templateCount': state.agentTemplates.length,
            'selectedTemplate': landscape.id,
            'outputPath': outputPath,
            'validation': jsonDecode(state.agentResult!.validation!),
            'events': [
              for (final event in state.agentEvents)
                {'kind': event.kind.name, 'message': event.message},
            ],
          }),
        );
      });
      debugPrint('[client-e2e] exported $outputPath');
    },
    skip: !runClientE2e,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim() ?? '';
  if (value.isEmpty) throw StateError('Missing environment variable $name');
  return value;
}
