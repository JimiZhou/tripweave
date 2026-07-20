import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripweave/src/editing_agent_models.dart';
import 'package:tripweave/src/journey_history.dart';
import 'package:tripweave/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completed journey round-trips editable metadata without media bytes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final media =
          MediaItem(
              id: 'photo-1',
              name: '海边.jpg',
              kind: MediaKind.image,
              bytes: Uint8List.fromList([1, 2, 3]),
              importedAt: DateTime.utc(2026, 7, 18),
              byteLength: 3,
              sourcePath: '/photos/海边.jpg',
              width: 1200,
              height: 800,
            )
            ..selected = true
            ..status = ProcessingStatus.enhanced
            ..beautyPreset = BeautyPreset.natural;
      final template = AgentTemplateProposal(
        id: 'summer',
        name: '海边慢游',
        description: '舒缓的夏日记录',
        rationale: '从人物出发，以海景收尾。',
        accent: 'sun',
        plan: const AgentEditPlan(
          title: '海边的一天',
          style: '舒缓',
          ratio: VlogRatio.landscape,
          musicId: 'martini-sunset',
          clips: [
            AgentClipPlan(
              mediaId: 'photo-1',
              durationMs: 3200,
              caption: '海风正好',
            ),
          ],
        ),
      );
      final journey = CompletedJourney(
        id: 'journey-1',
        title: '海边的一天',
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18, 1),
        assets: [JourneyAssetRecord.fromMedia(media)],
        templates: [template],
        selectedTemplateId: template.id,
        userBrief: '人物互动多一点',
        renderedPath: '/movies/trip.mp4',
      );

      final store = JourneyHistoryStore();
      await store.save([journey]);
      final restored = await store.load();

      expect(restored, hasLength(1));
      expect(restored.single.title, '海边的一天');
      expect(restored.single.assets.single.sourcePath, '/photos/海边.jpg');
      expect(restored.single.selectedTemplate?.plan.musicId, 'martini-sunset');
      expect(
        restored.single.selectedTemplate?.plan.clips.single.durationMs,
        3200,
      );
      expect(restored.single.userBrief, '人物互动多一点');
    },
  );
}
