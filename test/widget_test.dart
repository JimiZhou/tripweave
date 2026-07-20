import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/main.dart' as app;
import 'package:tripweave/src/app.dart';
import 'package:tripweave/src/app_state.dart';
import 'package:tripweave/src/editing_agent_models.dart';
import 'package:tripweave/src/models.dart';

void main() {
  testWidgets('TripWeave launches its guided creation flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('旅织 TripWeave'), findsOneWidget);
    expect(find.text('批量选择照片和视频'), findsOneWidget);
    expect(find.text('创作'), findsOneWidget);
    expect(find.text('已完成旅程'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('工作台'), findsNothing);
    expect(find.text('素材'), findsNothing);
    expect(find.text('Vlog'), findsNothing);
  });

  testWidgets('preview and timeline controls share one editing page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState();
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    for (var index = 0; index < 2; index++) {
      state.assets.add(
        MediaItem(
          id: 'photo-$index',
          name: '照片 ${index + 1}.png',
          kind: MediaKind.image,
          bytes: png,
          importedAt: DateTime.utc(2026, 7, 18, index),
          byteLength: png.length,
          width: 1,
          height: 1,
        ),
      );
    }
    state.agentTemplates = [
      const AgentTemplateProposal(
        id: 'journal',
        name: '旅行手帐',
        description: '轻松自然的旅行记录',
        rationale: '先看人物，再看风景。',
        accent: 'sun',
        plan: AgentEditPlan(
          title: '周末出发',
          style: '自然',
          ratio: VlogRatio.landscape,
          musicId: 'city-run',
          clips: [
            AgentClipPlan(mediaId: 'photo-0', durationMs: 2800, caption: '出发'),
            AgentClipPlan(mediaId: 'photo-1', durationMs: 2800, caption: '抵达'),
          ],
        ),
      ),
    ];
    state.selectedAgentTemplateId = 'journal';
    state.creationStep = CreationStep.preview;

    await tester.pumpWidget(TripWeaveApp(state: state));
    await tester.pump();

    expect(find.text('预览并调整'), findsOneWidget);
    expect(find.text('成片轨道'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('背景音乐'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('背景音乐'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('修改要求'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('修改要求'), findsOneWidget);
    expect(find.text('导出最终视频'), findsOneWidget);
    expect(find.textContaining('进入时间轴'), findsNothing);
  });
}
