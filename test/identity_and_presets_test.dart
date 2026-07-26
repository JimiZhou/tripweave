import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripweave/src/app_state.dart';
import 'package:tripweave/src/identity.dart';
import 'package:tripweave/src/model_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('admin passcode is salted, verified, and never stored in plain text',
      () async {
    final store = IdentityStore();
    expect(await store.hasAdminPasscode(), isFalse);

    await store.saveAdminPasscode('trip-2026');
    expect(await store.hasAdminPasscode(), isTrue);
    expect(await store.verifyAdminPasscode('trip-2026'), isTrue);
    expect(await store.verifyAdminPasscode('wrong'), isFalse);

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString('tripweave.admin-passcode.v1');
    expect(stored, isNotNull);
    expect(stored!.contains('trip-2026'), isFalse);
  });

  test('traveler sign-in persists a device profile and restores it', () async {
    final state = AppState();
    await state.signInTraveler('阿织');
    expect(state.identity?.displayName, '阿织');
    expect(state.identity?.isAdmin, isFalse);

    final restored = AppState();
    await restored.restoreSession();
    expect(restored.sessionRestored, isTrue);
    expect(restored.identity?.displayName, '阿织');
  });

  test('first admin sign-in provisions the passcode, later ones verify it',
      () async {
    final state = AppState();
    await state.signInAdmin('站长', 'pass-1234');
    expect(state.identity?.isAdmin, isTrue);
    expect(state.adminPasscodeConfigured, isTrue);
    await state.signOut();
    expect(state.identity, isNull);

    await state.signInAdmin('站长', 'wrong-pass');
    expect(state.identity, isNull);
    expect(state.error, contains('管理口令不正确'));

    await state.signInAdmin('站长', 'pass-1234');
    expect(state.identity?.isAdmin, isTrue);
  });

  test('admin presets persist, apply without exposing keys, and set defaults',
      () async {
    final admin = AppState();
    await admin.restoreSession();
    const preset = ModelPreset(
      id: 'studio',
      name: '工作室通道',
      endpoint: 'https://llm.example.com/v1/chat/completions',
      planningModel: 'planner-1',
      visionModel: 'vision-1',
      apiKey: 'sk-secret',
      note: '适合 3 分钟以内短片',
    );
    await admin.saveModelPreset(preset);
    await admin.setDefaultModelPreset('studio');

    // A traveler on the same device gets the default preset applied on start
    // without ever entering an endpoint or key.
    final traveler = AppState();
    await traveler.restoreSession();
    expect(traveler.modelPresets, hasLength(1));
    expect(traveler.visionConfig.isReady, isTrue);
    expect(traveler.visionConfig.planningModel, 'planner-1');
    expect(traveler.activeModelPresetId, 'studio');

    // Deleting the preset clears the default and the active configuration.
    await admin.deleteModelPreset('studio');
    expect(admin.modelPresets, isEmpty);
    expect(admin.defaultModelPresetId, isNull);

    final afterDelete = AppState();
    await afterDelete.restoreSession();
    expect(afterDelete.modelPresets, isEmpty);
    expect(afterDelete.visionConfig.isReady, isFalse);
  });

  test('unusable presets are rejected on apply with admin guidance', () async {
    final state = AppState();
    const broken = ModelPreset(
      id: 'broken',
      name: '缺密钥',
      endpoint: 'https://llm.example.com/v1/chat/completions',
      planningModel: 'planner-1',
      apiKey: '',
    );
    state.modelPresets = [broken];
    state.applyModelPreset(broken);
    expect(state.visionConfig.isReady, isFalse);
    expect(state.error, contains('联系管理员'));
  });
}
