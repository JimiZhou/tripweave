import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'editing_agent.dart';
import 'editing_agent_models.dart';
import 'identity.dart';
import 'journey_history.dart';
import 'model_presets.dart';
import 'models.dart';
import 'music_catalog.dart';
import 'platform_video_saver.dart';
import 'services.dart';
import 'source_file.dart';
import 'update_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    JourneyHistoryStore? historyStore,
    UpdateService? updateService,
    IdentityStore? identityStore,
    ModelPresetStore? presetStore,
  }) : _historyStore = historyStore ?? JourneyHistoryStore(),
       _updateService = updateService ?? UpdateService(),
       _identityStore = identityStore ?? IdentityStore(),
       _presetStore = presetStore ?? ModelPresetStore();

  final JourneyHistoryStore _historyStore;
  final UpdateService _updateService;
  final IdentityStore _identityStore;
  final ModelPresetStore _presetStore;
  TripIdentity? identity;
  bool sessionRestored = false;
  bool adminPasscodeConfigured = false;
  List<ModelPreset> modelPresets = [];
  String? defaultModelPresetId;
  String? activeModelPresetId;
  final List<MediaItem> assets = [];
  List<CompletedJourney> completedJourneys = [];
  final Map<String, List<String>> missingJourneyAssets = {};
  final Set<String> availableJourneyOutputs = {};

  bool isImporting = false;
  bool isEnhancing = false;
  bool isGenerating = false;
  int currentSection = 0;
  CreationStep creationStep = CreationStep.import;
  double globalBeautyLevel = .62;
  BeautyPreset beautyPreset = BeautyPreset.natural;
  VlogStyle vlogStyle = VlogStyle.postcard;
  VlogRatio vlogRatio = VlogRatio.portrait;
  VlogDraft? draft;
  VisionLlmConfig visionConfig = const VisionLlmConfig();
  final List<AgentEvent> agentEvents = [];
  List<AgentTemplateProposal> agentTemplates = [];
  String? selectedAgentTemplateId;
  AgentRunResult? agentResult;
  bool isAgentAnalyzing = false;
  bool isAgentRendering = false;
  double agentRenderProgress = 0;
  String agentUserBrief = '';
  Uint8List? localMusicBytes;
  String? localMusicName;
  String? localMusicPath;
  String? activeJourneyId;
  String? notice;
  String? error;
  AvailableUpdate? availableUpdate;

  int get imageCount =>
      assets.where((asset) => asset.kind == MediaKind.image).length;
  int get videoCount =>
      assets.where((asset) => asset.kind == MediaKind.video).length;
  int get enhancedCount => assets.where((asset) => asset.isEnhanced).length;
  int get selectedCount => assets.where((asset) => asset.selected).length;
  AgentTemplateProposal? get selectedAgentTemplate {
    final matches = agentTemplates.where(
      (template) => template.id == selectedAgentTemplateId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  void goTo(int section) {
    currentSection = section.clamp(0, 2);
    notifyListeners();
  }

  void goToCreationStep(CreationStep step) {
    creationStep = step;
    currentSection = 0;
    notifyListeners();
  }

  Future<void> startNewCreation() async {
    assets.clear();
    draft = null;
    creationStep = CreationStep.import;
    agentTemplates = [];
    selectedAgentTemplateId = null;
    agentResult = null;
    agentEvents.clear();
    agentRenderProgress = 0;
    agentUserBrief = '';
    localMusicBytes = null;
    localMusicName = null;
    localMusicPath = null;
    activeJourneyId = null;
    currentSection = 0;
    notice = '已开始新的创作。';
    error = null;
    await _refreshJourneyAvailability();
    notifyListeners();
  }

  Future<void> restoreJourneyHistory() async {
    completedJourneys = await _historyStore.load();
    await _refreshJourneyAvailability();
    notifyListeners();
  }

  ModelPreset? get activeModelPreset {
    final matches = modelPresets.where(
      (preset) => preset.id == activeModelPresetId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> restoreSession() async {
    try {
      identity = await _identityStore.loadIdentity();
      adminPasscodeConfigured = await _identityStore.hasAdminPasscode();
      modelPresets = await _presetStore.load();
      defaultModelPresetId = await _presetStore.loadDefaultId();
      final defaults = modelPresets.where(
        (preset) => preset.id == defaultModelPresetId && preset.isUsable,
      );
      if (!visionConfig.isReady && defaults.isNotEmpty) {
        visionConfig = defaults.first.toConfig();
        activeModelPresetId = defaults.first.id;
      }
    } catch (_) {
      // A broken local store must never lock the user out of the workspace.
    } finally {
      sessionRestored = true;
      notifyListeners();
    }
  }

  Future<void> signInTraveler(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      error = '起个名字，让作品署名更有旅行感。';
      notifyListeners();
      return;
    }
    identity = TripIdentity(
      displayName: trimmed,
      role: TripRole.traveler,
      signedInAt: DateTime.now(),
    );
    await _identityStore.saveIdentity(identity!);
    error = null;
    notice = '欢迎回来，$trimmed。素材和成片都留在这台设备上。';
    notifyListeners();
  }

  Future<void> signInAdmin(String name, String passcode) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      error = '请填写管理员名称。';
      notifyListeners();
      return;
    }
    if (passcode.trim().length < 4) {
      error = '管理口令至少 4 位。';
      notifyListeners();
      return;
    }
    final firstSetup = !adminPasscodeConfigured;
    if (adminPasscodeConfigured) {
      final ok = await _identityStore.verifyAdminPasscode(passcode.trim());
      if (!ok) {
        error = '管理口令不正确。';
        notifyListeners();
        return;
      }
    } else {
      await _identityStore.saveAdminPasscode(passcode.trim());
      adminPasscodeConfigured = true;
    }
    identity = TripIdentity(
      displayName: trimmed,
      role: TripRole.admin,
      signedInAt: DateTime.now(),
    );
    await _identityStore.saveIdentity(identity!);
    error = null;
    notice = firstSetup
        ? '已创建本机管理口令，$trimmed 现在可以维护模型预置。'
        : '管理员 $trimmed 已登录，可在设置中维护模型预置。';
    notifyListeners();
  }

  Future<void> signOut() async {
    identity = null;
    await _identityStore.clearIdentity();
    notice = null;
    error = null;
    currentSection = 0;
    notifyListeners();
  }

  Future<void> saveModelPreset(ModelPreset preset) async {
    final index = modelPresets.indexWhere((item) => item.id == preset.id);
    if (index >= 0) {
      modelPresets[index] = preset;
    } else {
      modelPresets.add(preset);
    }
    await _presetStore.save(modelPresets);
    if (activeModelPresetId == preset.id) {
      visionConfig = preset.toConfig();
    }
    notice = '模型预置“${preset.name}”已保存，旅行者选择后即可直接使用。';
    notifyListeners();
  }

  Future<void> deleteModelPreset(String id) async {
    final removed = modelPresets.where((preset) => preset.id == id).toList();
    if (removed.isEmpty || removed.first.builtIn) return;
    modelPresets.removeWhere((preset) => preset.id == id);
    await _presetStore.save(modelPresets);
    if (defaultModelPresetId == id) {
      defaultModelPresetId = null;
      await _presetStore.saveDefaultId(null);
    }
    if (activeModelPresetId == id) {
      activeModelPresetId = null;
      visionConfig = const VisionLlmConfig();
    }
    notice = '已删除预置“${removed.first.name}”。';
    notifyListeners();
  }

  Future<void> setDefaultModelPreset(String? id) async {
    defaultModelPresetId = id;
    await _presetStore.saveDefaultId(id);
    notice = id == null ? '已取消默认预置。' : '新用户进入时将自动启用该预置。';
    notifyListeners();
  }

  void applyModelPreset(ModelPreset preset) {
    if (!preset.isUsable) {
      error = '该预置缺少接口地址、模型或密钥，请联系管理员补全。';
      notifyListeners();
      return;
    }
    visionConfig = preset.toConfig();
    activeModelPresetId = preset.id;
    error = null;
    notice = '已启用“${preset.name}”，可以直接开始 AI 剪辑，无需填写密钥。';
    notifyListeners();
  }

  Future<void> _refreshJourneyAvailability() async {
    missingJourneyAssets.clear();
    availableJourneyOutputs.clear();
    final currentById = {for (final asset in assets) asset.id: asset};
    for (final journey in completedJourneys) {
      final missing = <String>[];
      for (final asset in journey.assets) {
        final current = currentById[asset.id];
        final availableInMemory = current != null && current.bytes.isNotEmpty;
        if (!availableInMemory && !await sourceFileExists(asset.sourcePath)) {
          missing.add(asset.name);
        }
      }
      if (journey.selectedTemplate?.plan.musicId == 'local') {
        final availableInMemory =
            activeJourneyId == journey.id &&
            localMusicBytes?.isNotEmpty == true;
        if (!availableInMemory &&
            !await sourceFileExists(journey.localMusicPath)) {
          missing.add('本地音乐：${journey.localMusicName ?? '未命名文件'}');
        }
      } else if (journey.selectedTemplate != null &&
          !MusicCatalog.containsId(journey.selectedTemplate!.plan.musicId)) {
        missing.add('在线音乐：${journey.musicTitle ?? '已下架曲目'}');
      }
      if (missing.isNotEmpty) missingJourneyAssets[journey.id] = missing;
      if (await sourceFileExists(journey.renderedPath)) {
        availableJourneyOutputs.add(journey.id);
      }
    }
  }

  bool canEditJourney(CompletedJourney journey) =>
      !missingJourneyAssets.containsKey(journey.id);

  Future<void> openCompletedJourney(CompletedJourney journey) async {
    await _refreshJourneyAvailability();
    final missing = missingJourneyAssets[journey.id];
    if (missing != null && missing.isNotEmpty) {
      error = kIsWeb
          ? '浏览器未保留原始文件权限。请重新选择原素材后再创作。'
          : '原始素材已移动或删除，无法继续编辑：${missing.take(3).join('、')}${missing.length > 3 ? ' 等 ${missing.length} 个文件' : ''}。';
      notice = null;
      notifyListeners();
      return;
    }

    final restoredAssets = <MediaItem>[];
    try {
      final existingLocalMusicBytes = activeJourneyId == journey.id
          ? localMusicBytes
          : null;
      final currentById = {for (final asset in assets) asset.id: asset};
      for (final record in journey.assets) {
        final current = currentById[record.id];
        final bytes = current?.bytes.isNotEmpty == true
            ? current!.bytes
            : record.kind == MediaKind.image
            ? await readSourceFile(record.sourcePath!)
            : Uint8List(0);
        final asset = MediaItem(
          id: record.id,
          name: record.name,
          kind: record.kind,
          bytes: bytes,
          importedAt: record.importedAt,
          byteLength: record.byteLength,
          sourcePath: record.sourcePath,
          width: record.width,
          height: record.height,
        );
        asset.selected = record.selected;
        asset.status = record.status;
        asset.beautyLevel = record.beautyLevel;
        asset.beautyPreset = record.beautyPreset;
        restoredAssets.add(asset);
      }
      assets
        ..clear()
        ..addAll(restoredAssets);
      agentTemplates = List.of(journey.templates);
      selectedAgentTemplateId = journey.selectedTemplateId;
      agentUserBrief = journey.userBrief;
      localMusicName = journey.localMusicName;
      localMusicPath = journey.localMusicPath;
      localMusicBytes = journey.localMusicPath == null
          ? existingLocalMusicBytes
          : await readSourceFile(journey.localMusicPath!);
      final template = selectedAgentTemplate;
      final renderedAvailable = await sourceFileExists(journey.renderedPath);
      agentResult = template == null
          ? null
          : AgentRunResult(
              plan: template.plan,
              summary: '已恢复历史工程。',
              renderedPath: renderedAvailable ? journey.renderedPath : null,
              validation: journey.validation,
            );
      activeJourneyId = journey.id;
      creationStep = CreationStep.preview;
      currentSection = 0;
      error = null;
      notice = renderedAvailable
          ? '已打开“${journey.title}”，可以继续调整。'
          : '已恢复工程，原预览已清理；重新生成即可继续预览。';
    } catch (exception) {
      error = '没有恢复这个工程。请确认原始素材仍可访问。\n$exception';
    }
    notifyListeners();
  }

  Future<void> removeCompletedJourney(CompletedJourney journey) async {
    completedJourneys.removeWhere((item) => item.id == journey.id);
    missingJourneyAssets.remove(journey.id);
    availableJourneyOutputs.remove(journey.id);
    await _historyStore.save(completedJourneys);
    notice = '已移除“${journey.title}”的历史记录，原始素材和视频未被删除。';
    notifyListeners();
  }

  void clearMessage() {
    notice = null;
    error = null;
    notifyListeners();
  }

  Future<void> checkForUpdate() async {
    try {
      availableUpdate = await _updateService.check();
      if (availableUpdate != null) notifyListeners();
    } catch (_) {
      // Update checks never block local creation or offline startup.
    }
  }

  Future<void> installAvailableUpdate() async {
    final update = availableUpdate;
    if (update == null) return;
    final opened = await _updateService.open(update);
    if (!opened) {
      error = '没有打开更新下载页，请稍后重试。';
      notifyListeners();
    }
  }

  void dismissAvailableUpdate() {
    availableUpdate = null;
    notifyListeners();
  }

  Future<void> importMedia() async {
    if (isImporting) return;
    isImporting = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      final files = await openFiles(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '照片与视频',
            extensions: [
              'jpg',
              'jpeg',
              'png',
              'webp',
              'heic',
              'mp4',
              'mov',
              'm4v',
              'webm',
            ],
          ),
        ],
      );
      if (files.isEmpty) return;
      await importMediaFiles(files);
    } catch (exception) {
      error = '没有完成导入。请确认文件格式可用后重试。\n$exception';
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  Future<void> importMediaFiles(List<XFile> files) async {
    var imported = 0;
    for (final file in files) {
      final lower = file.name.toLowerCase();
      final isVideo =
          file.mimeType?.toLowerCase().startsWith('video/') == true ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.m4v') ||
          lower.endsWith('.webm');
      // Native video files can be hundreds of megabytes. Keep the picker-backed
      // path and let FFmpeg read it on demand instead of duplicating every video
      // into the Dart heap as soon as the picker closes.
      final hasNativeSource = !kIsWeb && file.path.trim().isNotEmpty;
      final keepVideoOnDisk = isVideo && hasNativeSource;
      final bytes = keepVideoOnDisk
          ? Uint8List(0)
          : Uint8List.fromList(await file.readAsBytes());
      final byteLength = await file.length();
      DecodedImageInfo? dimensions;
      if (!isVideo) {
        dimensions = await BeautyService.inspect(bytes);
        if (dimensions == null) continue;
      }
      assets.add(
        MediaItem(
          id: '${DateTime.now().microsecondsSinceEpoch}-${assets.length}',
          name: file.name,
          kind: isVideo ? MediaKind.video : MediaKind.image,
          bytes: bytes,
          importedAt: DateTime.now().add(Duration(milliseconds: assets.length)),
          byteLength: byteLength,
          sourcePath: hasNativeSource ? file.path : null,
          width: dimensions?.width,
          height: dimensions?.height,
        ),
      );
      imported++;
    }
    notice = '已导入 $imported 个素材，文件只在当前设备使用。';
    if (imported > 0) creationStep = CreationStep.curate;
    notifyListeners();
  }

  Future<void> enhanceAll() async {
    if (isEnhancing) return;
    final targets = assets
        .where((asset) => asset.kind == MediaKind.image && asset.selected)
        .toList();
    if (targets.isEmpty) {
      error = '请先选择至少一张照片，再开始自动美化。';
      notifyListeners();
      return;
    }
    isEnhancing = true;
    error = null;
    notice = null;
    for (final target in targets) {
      target.status = ProcessingStatus.queued;
    }
    notifyListeners();

    var completed = 0;
    for (final target in targets) {
      target.status = ProcessingStatus.processing;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 28));
      target.beautyLevel = globalBeautyLevel;
      target.beautyPreset = beautyPreset;
      target.status = ProcessingStatus.enhanced;
      completed++;
      notifyListeners();
    }
    isEnhancing = false;
    notice = '已完成 $completed 张照片的自然人像优化。';
    notifyListeners();
  }

  void restoreOriginal(MediaItem asset) {
    asset.enhancedBytes = null;
    asset.status = ProcessingStatus.original;
    notifyListeners();
  }

  void toggleSelection(MediaItem asset) {
    asset.selected = !asset.selected;
    notifyListeners();
  }

  void selectAllAssets() {
    for (final asset in assets) {
      asset.selected = true;
    }
    notifyListeners();
  }

  void clearAssetSelection() {
    for (final asset in assets) {
      asset.selected = false;
    }
    notifyListeners();
  }

  void removeAsset(MediaItem asset) {
    assets.remove(asset);
    draft = null;
    agentTemplates = [];
    selectedAgentTemplateId = null;
    agentResult = null;
    notice = '已从本次旅程移除，可重新导入恢复。';
    notifyListeners();
  }

  void setBeautyLevel(double value) {
    globalBeautyLevel = value;
    notifyListeners();
  }

  void setBeautyPreset(BeautyPreset value) {
    beautyPreset = value;
    notifyListeners();
  }

  void setVisionConfig(VisionLlmConfig value) {
    visionConfig = value;
    activeModelPresetId = null;
    notice = value.enabled
        ? '剪辑服务已启用：${value.effectiveVisionModel} 分析画面，${value.planningModel.trim()} 编排视频。'
        : '剪辑服务已关闭，素材整理和人像优化仍可在本机使用。';
    notifyListeners();
  }

  Future<void> refreshMusicCatalog() async {
    await MusicCatalog.refresh(force: true);
    notifyListeners();
  }

  void setStyle(VlogStyle value) {
    vlogStyle = value;
    notifyListeners();
  }

  void setRatio(VlogRatio value) {
    vlogRatio = value;
    notifyListeners();
  }

  Future<void> generateVlog({String title = ''}) async {
    if (isGenerating) return;
    if (selectedCount < 2) {
      error = '至少选择 2 个片段，才能让旅程形成节奏。';
      notifyListeners();
      return;
    }
    isGenerating = true;
    error = null;
    notice = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 850));
    draft = VlogService.generate(
      assets: assets,
      title: title,
      style: vlogStyle,
      ratio: vlogRatio,
    );
    isGenerating = false;
    currentSection = 0;
    notice = '旅行 Vlog 初稿已生成，可以继续调整风格和画幅。';
    notifyListeners();
  }

  Future<void> exportProject() async {
    final current = draft;
    if (current == null) return;
    try {
      final location = await getSaveLocation(
        suggestedName:
            'tripweave-${DateTime.now().millisecondsSinceEpoch}.json',
      );
      if (location == null) return;
      final text = VlogService.encodeProject(current, assets);
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(text)),
        mimeType: 'application/json',
        name: 'tripweave-project.json',
      );
      await file.saveTo(location.path);
      notice = 'Vlog 工程已导出，可交给后续高清渲染器继续制作。';
    } catch (exception) {
      error = '当前平台没有完成工程导出，请在 Web 或桌面端重试。\n$exception';
    }
    notifyListeners();
  }

  Future<void> analyzeWithEditingAgent() async {
    if (isAgentAnalyzing) return;
    if (!visionConfig.isReady) {
      error = modelPresets.isNotEmpty
          ? '请先在设置中选择一个管理员预置的剪辑服务，或手动填写接口配置。'
          : '请先在设置中填写接口地址、规划模型和 API 密钥；视觉模型可留空并复用规划模型。';
      notifyListeners();
      return;
    }
    if (selectedCount < 2) {
      error = '至少选择两个照片或视频素材，再开始分析。';
      notifyListeners();
      return;
    }
    isAgentAnalyzing = true;
    creationStep = CreationStep.analyze;
    agentEvents.clear();
    agentTemplates = [];
    selectedAgentTemplateId = null;
    agentResult = null;
    error = null;
    notice = '正在分析素材并准备三个模板…';
    notifyListeners();
    try {
      agentTemplates = await const EditingAgent().proposeTemplates(
        config: visionConfig,
        assets: assets,
        userBrief: agentUserBrief,
        onEvent: (event) {
          agentEvents.add(event);
          notifyListeners();
        },
      );
      selectedAgentTemplateId = agentTemplates.first.id;
      creationStep = CreationStep.templates;
      notice = '已准备 ${agentTemplates.length} 个模板，选择一个继续。';
    } catch (exception) {
      error = '没有完成素材分析。请检查视觉模型是否支持图片输入、规划模型是否支持工具调用。\n$exception';
    } finally {
      isAgentAnalyzing = false;
      notifyListeners();
    }
  }

  void selectAgentTemplate(String id) {
    selectedAgentTemplateId = id;
    agentResult = null;
    agentRenderProgress = 0;
    notifyListeners();
  }

  void confirmAgentTemplate() {
    if (selectedAgentTemplate == null) {
      error = '请先选择一个剪辑模板。';
      notifyListeners();
      return;
    }
    creationStep = CreationStep.preview;
    error = null;
    notifyListeners();
  }

  void openTimeline() {
    if (agentResult?.renderedPath == null) {
      error = '请先生成一次带声音预览。';
      notifyListeners();
      return;
    }
    creationStep = CreationStep.timeline;
    notifyListeners();
  }

  void _replaceSelectedAgentPlan(AgentEditPlan plan) {
    final template = selectedAgentTemplate;
    if (template == null) return;
    final index = agentTemplates.indexWhere((item) => item.id == template.id);
    if (index < 0) return;
    agentTemplates[index] = AgentTemplateProposal(
      id: template.id,
      name: template.name,
      description: template.description,
      rationale: template.rationale,
      accent: template.accent,
      plan: plan,
    );
    agentResult = null;
    agentRenderProgress = 0;
    notifyListeners();
  }

  void setAgentUserBrief(String value) {
    agentUserBrief = value;
  }

  void moveAgentClip(int index, int offset) {
    final template = selectedAgentTemplate;
    if (template == null) return;
    final target = index + offset;
    if (index < 0 || target < 0 || target >= template.plan.clips.length) return;
    final clips = List<AgentClipPlan>.of(template.plan.clips);
    final clip = clips.removeAt(index);
    clips.insert(target, clip);
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void adjustAgentClipDuration(int index, int deltaMs) {
    final template = selectedAgentTemplate;
    if (template == null || index < 0 || index >= template.plan.clips.length) {
      return;
    }
    final clips = List<AgentClipPlan>.of(template.plan.clips);
    final current = clips[index];
    clips[index] = AgentClipPlan(
      mediaId: current.mediaId,
      startMs: current.startMs,
      durationMs: (current.durationMs + deltaMs).clamp(1200, 8000),
      caption: current.caption,
    );
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void adjustAgentClipStart(int index, int deltaMs) {
    final template = selectedAgentTemplate;
    if (template == null || index < 0 || index >= template.plan.clips.length) {
      return;
    }
    final clips = List<AgentClipPlan>.of(template.plan.clips);
    final current = clips[index];
    clips[index] = AgentClipPlan(
      mediaId: current.mediaId,
      startMs: (current.startMs + deltaMs).clamp(0, 60000),
      durationMs: current.durationMs,
      caption: current.caption,
    );
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void setAgentClipRange({
    required int index,
    required int startMs,
    required int durationMs,
  }) {
    final template = selectedAgentTemplate;
    if (template == null || index < 0 || index >= template.plan.clips.length) {
      return;
    }
    final clips = List<AgentClipPlan>.of(template.plan.clips);
    final current = clips[index];
    clips[index] = AgentClipPlan(
      mediaId: current.mediaId,
      startMs: startMs.clamp(0, 60000),
      durationMs: durationMs.clamp(1200, 8000),
      caption: current.caption,
    );
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void removeAgentClip(int index) {
    final template = selectedAgentTemplate;
    if (template == null || template.plan.clips.length <= 2) {
      error = '成片至少保留两个片段。';
      notifyListeners();
      return;
    }
    final clips = List<AgentClipPlan>.of(template.plan.clips)..removeAt(index);
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void toggleAgentPlanAsset(MediaItem asset) {
    final template = selectedAgentTemplate;
    if (template == null) return;
    final clips = List<AgentClipPlan>.of(template.plan.clips);
    final index = clips.indexWhere((clip) => clip.mediaId == asset.id);
    if (index >= 0) {
      if (clips.length <= 2) {
        error = '成片至少保留两个片段。';
        notifyListeners();
        return;
      }
      clips.removeAt(index);
    } else {
      clips.add(
        AgentClipPlan(
          mediaId: asset.id,
          durationMs: asset.kind == MediaKind.image ? 2800 : 4000,
          caption: asset.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        ),
      );
    }
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void setAgentMusic(String musicId) {
    final template = selectedAgentTemplate;
    if (template == null) return;
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: musicId,
        clips: template.plan.clips,
      ),
    );
    localMusicBytes = null;
    localMusicName = null;
    localMusicPath = null;
  }

  Future<void> importLocalMusic() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: '音乐', extensions: ['mp3', 'm4a', 'aac', 'wav']),
        ],
      );
      if (file == null) return;
      final bytes = Uint8List.fromList(await file.readAsBytes());
      if (bytes.isEmpty) throw StateError('音乐文件为空。');
      final template = selectedAgentTemplate;
      if (template == null) return;
      localMusicBytes = bytes;
      localMusicName = file.name;
      localMusicPath = !kIsWeb && file.path.trim().isNotEmpty
          ? file.path
          : null;
      _replaceSelectedAgentPlan(
        AgentEditPlan(
          title: template.plan.title,
          style: template.plan.style,
          ratio: template.plan.ratio,
          musicId: 'local',
          clips: template.plan.clips,
        ),
      );
      notice = '已使用本地音乐 ${file.name}，文件不会上传。';
    } catch (exception) {
      error = '没有完成本地音乐导入。$exception';
    }
    notifyListeners();
  }

  void replaceAgentClip(int index, MediaItem replacement) {
    final template = selectedAgentTemplate;
    if (template == null || index < 0 || index >= template.plan.clips.length) {
      return;
    }
    final clips = List<AgentClipPlan>.of(template.plan.clips);
    final current = clips[index];
    clips[index] = AgentClipPlan(
      mediaId: replacement.id,
      startMs: 0,
      durationMs: current.durationMs,
      caption: replacement.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: template.plan.ratio,
        musicId: template.plan.musicId,
        clips: clips,
      ),
    );
  }

  void setAgentRatio(VlogRatio ratio) {
    final template = selectedAgentTemplate;
    if (template == null) return;
    _replaceSelectedAgentPlan(
      AgentEditPlan(
        title: template.plan.title,
        style: template.plan.style,
        ratio: ratio,
        musicId: template.plan.musicId,
        clips: template.plan.clips,
      ),
    );
  }

  Future<void> renderSelectedAgentTemplate() async {
    final template = selectedAgentTemplate;
    if (template == null || isAgentRendering) return;
    isAgentRendering = true;
    agentRenderProgress = 0;
    error = null;
    notice = '正在生成视频并检查输出…';
    notifyListeners();
    try {
      agentResult = await const EditingAgent().renderTemplate(
        template: template,
        assets: assets,
        musicBytes: template.plan.musicId == 'local' ? localMusicBytes : null,
        onEvent: (event) {
          agentEvents.add(event);
          notifyListeners();
        },
        onProgress: (progress) {
          agentRenderProgress = progress;
          notifyListeners();
        },
      );
      await _saveCompletedJourney();
      notice = agentResult!.summary;
    } catch (exception) {
      error = '没有完成视频输出，请重试。\n$exception';
    } finally {
      isAgentRendering = false;
      notifyListeners();
    }
  }

  Future<void> saveRenderedVideo() async {
    final path = agentResult?.renderedPath;
    if (path == null) return;
    try {
      final suggestedName =
          'tripweave-${DateTime.now().millisecondsSinceEpoch}.mp4';
      final systemLocation = await saveVideoToSystemLibrary(
        sourcePath: path,
        suggestedName: suggestedName,
      );
      if (systemLocation != null) {
        notice = 'MP4 成片已保存到系统相册 · Movies/TripWeave。';
        error = null;
        notifyListeners();
        return;
      }
      final location = await getSaveLocation(suggestedName: suggestedName);
      if (location == null) return;
      if (path.startsWith('data:video/mp4;base64,')) {
        final bytes = base64Decode(path.substring(path.indexOf(',') + 1));
        await XFile.fromData(
          bytes,
          mimeType: 'video/mp4',
          name: 'tripweave.mp4',
        ).saveTo(location.path);
      } else {
        await XFile(path).saveTo(location.path);
      }
      notice = 'MP4 成片已保存到选择的位置。';
      error = null;
    } catch (exception) {
      error = '没有完成 MP4 保存。成片仍保留在预览中，可重试保存。\n$exception';
    }
    notifyListeners();
  }

  Future<void> exportFinalVideo() async {
    if (agentResult?.renderedPath == null) {
      await renderSelectedAgentTemplate();
    }
    if (agentResult?.renderedPath == null) return;
    await saveRenderedVideo();
    if (error == null) {
      await _saveCompletedJourney();
      creationStep = CreationStep.export;
      notifyListeners();
    }
  }

  Future<void> _saveCompletedJourney() async {
    final template = selectedAgentTemplate;
    if (template == null || agentResult?.renderedPath == null) return;
    final now = DateTime.now();
    final music = template.plan.musicId == 'local'
        ? null
        : MusicCatalog.byId(template.plan.musicId);
    final existing = completedJourneys.where(
      (item) => item.id == activeJourneyId,
    );
    final id = activeJourneyId ?? 'journey-${now.microsecondsSinceEpoch}';
    final createdAt = existing.isEmpty ? now : existing.first.createdAt;
    final journey = CompletedJourney(
      id: id,
      title: template.plan.title.trim().isEmpty
          ? '未命名旅程'
          : template.plan.title.trim(),
      createdAt: createdAt,
      updatedAt: now,
      assets: assets.map(JourneyAssetRecord.fromMedia).toList(),
      templates: List.of(agentTemplates),
      selectedTemplateId: template.id,
      userBrief: agentUserBrief,
      localMusicName: localMusicName,
      localMusicPath: localMusicPath,
      musicTitle: music?.title ?? localMusicName,
      musicArtist: music?.artist,
      musicLicense: music?.license,
      musicSourceUrl: music?.sourceUrl,
      renderedPath: agentResult?.renderedPath,
      validation: agentResult?.validation,
    );
    completedJourneys.removeWhere((item) => item.id == id);
    completedJourneys.insert(0, journey);
    activeJourneyId = id;
    await _historyStore.save(completedJourneys);
    await _refreshJourneyAvailability();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this context.');
    return scope!.notifier!;
  }
}
