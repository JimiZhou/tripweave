import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'editing_agent_models.dart';
import 'gpu_beauty_image.dart';
import 'identity.dart';
import 'journey_history.dart';
import 'model_presets.dart';
import 'models.dart';
import 'music_catalog.dart';
import 'rendered_video_preview.dart';
import 'theme.dart';

class TripWeaveApp extends StatelessWidget {
  const TripWeaveApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: '旅织 TripWeave',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _destinations = [
    (Icons.video_call_outlined, Icons.video_call, '创作'),
    (Icons.route_outlined, Icons.route, '已完成旅程'),
    (Icons.tune_outlined, Icons.tune, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.sessionRestored) return const _SessionSplash();
    if (state.identity == null) return const WelcomePage();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        final content = Column(
          children: [
            _UpdateBanner(state: state),
            _MessageRibbon(state: state),
            Expanded(
              child: IndexedStack(
                index: state.currentSection,
                children: const [
                  CreationWizardPage(),
                  CompletedJourneysPage(),
                  SettingsPage(),
                ],
              ),
            ),
          ],
        );

        if (!desktop) {
          return Scaffold(
            body: SafeArea(bottom: false, child: content),
            bottomNavigationBar: NavigationBar(
              height: 72,
              backgroundColor: const Color(0xFFF1E8DA),
              indicatorColor: TripColors.ink,
              selectedIndex: state.currentSection,
              onDestinationSelected: state.goTo,
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.$1),
                    selectedIcon: Icon(destination.$2, color: TripColors.paper),
                    label: destination.$3,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _DesktopNavigation(
                selectedIndex: state.currentSection,
                onSelected: state.goTo,
                destinations: _destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _SessionSplash extends StatelessWidget {
  const _SessionSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandMark(),
            const SizedBox(height: 24),
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: TripColors.paprika,
                backgroundColor: TripColors.paperDeep,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '正在唤醒你的旅程…',
              style: TextStyle(color: Color(0xFF776C60)),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final nameController = TextEditingController();
  final passcodeController = TextEditingController();
  bool adminMode = false;
  bool obscurePasscode = true;

  @override
  void dispose() {
    nameController.dispose();
    passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final form = _buildForm(context, state);
    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: _WelcomeHeroPanel()),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: form,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildForm(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandMark(),
        const SizedBox(height: 30),
        Text(
          adminMode ? '管理员入口' : '欢迎回来，\n继续你的旅程',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontSize: MediaQuery.sizeOf(context).width < 600 ? 34 : 42,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          adminMode
              ? (state.adminPasscodeConfigured
                    ? '输入本机管理口令，维护旅行者可直接选用的模型预置。'
                    : '首次使用：设置本机管理口令（至少 4 位），之后即可预置剪辑模型。')
              : '登录只在这台设备上创建创作档案，素材、成片和历史都不会上传。',
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Color(0xFF62594F),
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: nameController,
          textInputAction: adminMode
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: adminMode ? null : (_) => _submit(state),
          decoration: InputDecoration(
            labelText: adminMode ? '管理员名称' : '你的名字',
            hintText: adminMode ? '例如：站点管理员' : '例如：阿织',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
        if (adminMode) ...[
          const SizedBox(height: 14),
          TextField(
            controller: passcodeController,
            obscureText: obscurePasscode,
            onSubmitted: (_) => _submit(state),
            decoration: InputDecoration(
              labelText: state.adminPasscodeConfigured ? '管理口令' : '设置管理口令',
              prefixIcon: const Icon(Icons.key_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => obscurePasscode = !obscurePasscode),
                tooltip: obscurePasscode ? '显示口令' : '隐藏口令',
                icon: Icon(
                  obscurePasscode ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 14),
          Text(
            state.error!,
            style: const TextStyle(
              color: TripColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () => _submit(state),
            icon: Icon(
              adminMode ? Icons.admin_panel_settings_outlined : Icons.flight_takeoff,
            ),
            label: Text(adminMode ? '进入管理' : '开始创作'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            state.clearMessage();
            setState(() => adminMode = !adminMode);
          },
          child: Text(adminMode ? '← 返回旅行者登录' : '管理员入口 · 预置剪辑模型'),
        ),
        const SizedBox(height: 18),
        const _PrivacyMark(),
      ],
    );
  }

  void _submit(AppState state) {
    if (adminMode) {
      state.signInAdmin(nameController.text, passcodeController.text);
    } else {
      state.signInTraveler(nameController.text);
    }
  }
}

class _WelcomeHeroPanel extends StatelessWidget {
  const _WelcomeHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TripColors.indigo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _AbstractTravelFrame(color: TripColors.indigo),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8830455B), Color(0x2230455B)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '把旅程\n织成 Vlog',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: TripColors.paper,
                    fontSize: 56,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '批量导入照片视频 · AI 生成三套剪辑模板 · 本机渲染导出 MP4',
                  style: TextStyle(
                    color: Color(0xFFD3DAD7),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<(IconData, IconData, String)> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      color: const Color(0xFFF1E8DA),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
      child: Column(
        children: [
          Semantics(
            label: '旅织 TripWeave 首页',
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: TripColors.paprika,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '旅',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: TripColors.paper,
                ),
              ),
            ),
          ),
          const SizedBox(height: 42),
          for (var i = 0; i < destinations.length; i++) ...[
            _NavButton(
              icon: selectedIndex == i
                  ? destinations[i].$2
                  : destinations[i].$1,
              label: destinations[i].$3,
              selected: selectedIndex == i,
              onTap: () => onSelected(i),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          _NavIdentityBadge(identity: AppStateScope.of(context).identity),
          const SizedBox(height: 14),
          const _PrivacyMark(compact: true),
        ],
      ),
    );
  }
}

class _NavIdentityBadge extends StatelessWidget {
  const _NavIdentityBadge({required this.identity});
  final TripIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final current = identity;
    if (current == null) return const SizedBox.shrink();
    return Tooltip(
      message: current.isAdmin
          ? '${current.displayName} · 管理员'
          : current.displayName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: current.isAdmin
                ? TripColors.sun
                : TripColors.moss,
            child: Text(
              current.initial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: current.isAdmin ? TripColors.ink : TripColors.paper,
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 82,
            child: Text(
              current.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? TripColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 23,
                color: selected ? TripColors.paper : TripColors.ink,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? TripColors.paper : TripColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRibbon extends StatelessWidget {
  const _MessageRibbon({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final message = state.error ?? state.notice;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: message == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(message),
              width: double.infinity,
              color: state.error != null ? TripColors.danger : TripColors.moss,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Icon(
                      state.error != null
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: TripColors.paper,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: TripColors.paper,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: state.clearMessage,
                      tooltip: '关闭提示',
                      icon: const Icon(Icons.close, color: TripColors.paper),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final update = state.availableUpdate;
    if (update == null) return const SizedBox.shrink();
    return Material(
      color: TripColors.indigo,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 9, 8, 9),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt, color: TripColors.paper),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '旅织 ${update.version} 可用 · ${update.notes}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TripColors.paper,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: state.installAvailableUpdate,
                style: TextButton.styleFrom(foregroundColor: TripColors.sun),
                child: Text(kIsWeb ? '刷新更新' : '下载更新'),
              ),
              IconButton(
                onPressed: state.dismissAvailableUpdate,
                tooltip: '稍后更新',
                icon: const Icon(Icons.close, color: TripColors.paper),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreationWizardPage extends StatelessWidget {
  const CreationWizardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final step = state.creationStep;
    return Column(
      children: [
        if (step != CreationStep.import) _CreationProgress(step: step),
        Expanded(
          child: switch (step) {
            CreationStep.import => _ImportStep(state: state),
            CreationStep.curate => _CurateStep(state: state),
            CreationStep.analyze => _AnalyzeStep(state: state),
            CreationStep.templates => _TemplatesStep(state: state),
            CreationStep.preview => _PreviewStep(state: state),
            CreationStep.timeline => _TimelineStep(state: state),
            CreationStep.export => _ExportStep(state: state),
          },
        ),
      ],
    );
  }
}

class _CreationProgress extends StatelessWidget {
  const _CreationProgress({required this.step});
  final CreationStep step;

  static const labels = ['导入', '整理', '分析', '模板', '剪辑', '导出'];

  @override
  Widget build(BuildContext context) {
    final index = switch (step) {
      CreationStep.import => 0,
      CreationStep.curate => 1,
      CreationStep.analyze => 2,
      CreationStep.templates => 3,
      CreationStep.preview || CreationStep.timeline => 4,
      CreationStep.export => 5,
    };
    return Container(
      width: double.infinity,
      color: TripColors.paperDeep,
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
        12,
        MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
        12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Row(
              children: [
                Text(
                  '第 ${index + 1} / ${labels.length} 步 · ${labels[index]}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (index + 1) / labels.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Divider(
                      color: i <= index
                          ? TripColors.paprika
                          : const Color(0xFFCFC2B2),
                      thickness: 2,
                    ),
                  ),
                Semantics(
                  label: '第 ${i + 1} 步 ${labels[i]}',
                  selected: i == index,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: i <= index
                            ? TripColors.paprika
                            : const Color(0xFFD9CDBE),
                        foregroundColor: i <= index
                            ? TripColors.paper
                            : TripColors.ink,
                        child: i < index
                            ? const Icon(Icons.check, size: 17)
                            : Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 11),
                              ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == index
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ImportStep extends StatelessWidget {
  const _ImportStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandMark(),
              const SizedBox(height: 28),
              if (state.identity != null) ...[
                Text(
                  '你好，${state.identity!.displayName} · 新的旅程从这里开始',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: TripColors.paprikaDark,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '导入旅行素材，\n快速生成 Vlog',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width < 600 ? 42 : 58,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '一次多选照片和视频。选好素材和模板，即可预览并导出。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF62594F),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 62,
                child: FilledButton.icon(
                  onPressed: state.isImporting ? null : state.importMedia,
                  icon: state.isImporting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(state.isImporting ? '正在导入…' : '批量选择照片和视频'),
                ),
              ),
              if (state.assets.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => state.goToCreationStep(CreationStep.curate),
                  child: Text('继续当前创作 · ${state.assets.length} 个素材'),
                ),
              ],
              const SizedBox(height: 24),
              const _PrivacyMark(compact: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: TripColors.paprika,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            '旅',
            style: TextStyle(
              color: TripColors.paper,
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          '旅织 TripWeave',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _CurateStep extends StatelessWidget {
  const _CurateStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const LibraryPage(),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: TripColors.paper,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选 ${state.selectedCount} 个素材 · 支持多选',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: state.selectedCount < 2 || state.isAgentAnalyzing
                        ? null
                        : state.analyzeWithEditingAgent,
                    icon: const Icon(Icons.search),
                    label: const Text('分析素材'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyzeStep extends StatelessWidget {
  const _AnalyzeStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final progress = (state.agentEvents.length / 6).clamp(.08, .92);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const _AnalysisPulse(),
              const SizedBox(height: 24),
              Text('正在分析素材', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 9),
              const Text(
                '视觉模型正在观察代表画面，规划模型会据此编排三个中文模板。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF62594F), height: 1.55),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: state.isAgentAnalyzing ? progress : null,
                minHeight: 9,
                borderRadius: BorderRadius.circular(9),
              ),
              const SizedBox(height: 16),
              if (state.agentEvents.isNotEmpty)
                _AgentActivity(events: state.agentEvents),
              if (!state.isAgentAnalyzing && state.error != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: state.analyzeWithEditingAgent,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新分析'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisPulse extends StatefulWidget {
  const _AnalysisPulse();

  @override
  State<_AnalysisPulse> createState() => _AnalysisPulseState();
}

class _AnalysisPulseState extends State<_AnalysisPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: .92,
        end: 1.08,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: TripColors.indigo,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: TripColors.paprika.withValues(alpha: .28),
              blurRadius: 34,
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome, size: 42, color: TripColors.sun),
      ),
    );
  }
}

class _TemplatesStep extends StatelessWidget {
  const _TemplatesStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            28,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            90,
          ),
          sliver: SliverList.list(
            children: [
              Text(
                '选择一种讲述方式',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text('已根据人物、场景、光线和节奏准备三套方案。'),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 900
                      ? (constraints.maxWidth - 32) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final template in state.agentTemplates)
                        SizedBox(
                          width: width,
                          child: _AgentTemplateCard(
                            template: template,
                            selected:
                                template.id == state.selectedAgentTemplateId,
                            onTap: () => state.selectAgentTemplate(template.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: state.confirmAgentTemplate,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('使用这个模板并预览'),
              ),
              TextButton(
                onPressed: () => state.goToCreationStep(CreationStep.curate),
                child: const Text('返回调整素材'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final template = state.selectedAgentTemplate;
    if (template == null) return const SizedBox.shrink();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            28,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            90,
          ),
          sliver: SliverList.list(
            children: [
              Text('预览并调整', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text('边看边改：选择音乐、调整片段，满意后直接导出。'),
              const SizedBox(height: 20),
              _AgentTemplatePreview(state: state, template: template),
              const SizedBox(height: 18),
              _SimpleClipEditor(state: state, template: template),
              const SizedBox(height: 18),
              _MusicPicker(state: state, template: template),
              const SizedBox(height: 18),
              TextFormField(
                key: ValueKey('edit-brief-${template.id}'),
                initialValue: state.agentUserBrief,
                onChanged: state.setAgentUserBrief,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '修改要求',
                  hintText: '例如：开头快一些，多保留人物互动，结尾使用海边照片。',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: state.isAgentAnalyzing
                        ? null
                        : state.analyzeWithEditingAgent,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('按要求重新编排'),
                  ),
                  FilledButton.icon(
                    onPressed: state.isAgentRendering
                        ? null
                        : state.exportFinalVideo,
                    icon: state.isAgentRendering
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined),
                    label: Text(
                      state.isAgentRendering
                          ? '正在导出 ${(state.agentRenderProgress * 100).round()}%'
                          : '导出最终视频',
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => state.goToCreationStep(CreationStep.templates),
                child: const Text('返回选择其他模板'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MusicPicker extends StatelessWidget {
  const _MusicPicker({required this.state, required this.template});
  final AppState state;
  final AgentTemplateProposal template;

  @override
  Widget build(BuildContext context) {
    final onlineTrack = template.plan.musicId == 'local'
        ? null
        : MusicCatalog.byId(template.plan.musicId);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TripColors.paperDeep,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.library_music_outlined, color: TripColors.paprika),
              SizedBox(width: 9),
              Text(
                '背景音乐',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            initialValue: onlineTrack?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '在线曲库',
              prefixIcon: Icon(Icons.cloud_download_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final track in MusicCatalog.tracks)
                DropdownMenuItem(
                  value: track.id,
                  child: Text(
                    '${track.title} · ${track.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) state.setAgentMusic(value);
            },
          ),
          if (onlineTrack != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: TripColors.paper,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onlineTrack.mood,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text('${onlineTrack.artist} · ${onlineTrack.license}'),
                  const SizedBox(height: 5),
                  SelectableText(
                    '来源：${onlineTrack.sourceUrl}\n许可证：${onlineTrack.licenseUrl}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6E645A),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (template.plan.musicId == 'local')
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.audio_file_outlined),
              title: Text(state.localMusicName ?? '本地音乐'),
              subtitle: const Text('只在当前设备读取，不会上传'),
              trailing: const Icon(
                Icons.check_circle,
                color: TripColors.success,
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: state.importLocalMusic,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('添加本地歌曲'),
          ),
          const SizedBox(height: 8),
          const Text(
            '在线音乐在预览或导出时获取。曲名、作者、来源和许可证会随工程保存。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6E645A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return _PreviewStep(state: state);
  }
}

class _ExportStep extends StatelessWidget {
  const _ExportStep({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 86, color: TripColors.success),
            const SizedBox(height: 18),
            Text(
              '旅行 Vlog 已经完成',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text('视频已经通过硬件优先渲染和完整性验证。'),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: state.saveRenderedVideo,
              icon: const Icon(Icons.download_outlined),
              label: const Text('再次保存视频'),
            ),
            TextButton.icon(
              onPressed: state.startNewCreation,
              icon: const Icon(Icons.add),
              label: const Text('再次创作（清空当前素材）'),
            ),
            TextButton.icon(
              onPressed: () => state.goTo(1),
              icon: const Icon(Icons.route_outlined),
              label: const Text('查看已完成旅程'),
            ),
          ],
        ),
      ),
    );
  }
}

class CompletedJourneysPage extends StatelessWidget {
  const CompletedJourneysPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            30,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            18,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '创作记录',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                    color: TripColors.paprikaDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text('已完成旅程', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  kIsWeb
                      ? '工程记录保存在浏览器中。再次编辑时需要重新授权原始文件。'
                      : '工程会保留素材位置、模板、音乐和时间轴，原始文件不会被复制。',
                  style: const TextStyle(color: Color(0xFF62594F)),
                ),
              ],
            ),
          ),
        ),
        if (state.completedJourneys.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 58,
                        color: TripColors.paprika,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '还没有已完成的旅程',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '首次导出后，工程会自动出现在这里。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => state.goTo(0),
                        icon: const Icon(Icons.add),
                        label: const Text('开始创作'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
              8,
              MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
              90,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 430,
                mainAxisExtent: 260,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: state.completedJourneys.length,
              itemBuilder: (context, index) => _CompletedJourneyCard(
                state: state,
                journey: state.completedJourneys[index],
              ),
            ),
          ),
      ],
    );
  }
}

class _CompletedJourneyCard extends StatelessWidget {
  const _CompletedJourneyCard({required this.state, required this.journey});

  final AppState state;
  final CompletedJourney journey;

  @override
  Widget build(BuildContext context) {
    final editable = state.canEditJourney(journey);
    final missing = state.missingJourneyAssets[journey.id]?.length ?? 0;
    final date = journey.updatedAt.toLocal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TripColors.paperDeep,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8CCBB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: editable ? TripColors.moss : const Color(0xFF8B8175),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  editable ? Icons.movie_outlined : Icons.link_off,
                  color: TripColors.paper,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '移除记录',
                onPressed: () => _confirmRemove(context),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            journey.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${journey.assets.length} 个素材 · ${(journey.durationMs / 1000).toStringAsFixed(0)} 秒 · ${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Color(0xFF6E645A)),
          ),
          const SizedBox(height: 10),
          Text(
            editable
                ? '模板、时间轴和音乐均已保存'
                : kIsWeb
                ? '需要重新授权原始文件'
                : '$missing 个原始文件不可用',
            style: TextStyle(
              color: editable ? TripColors.success : TripColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDetails(context),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('查看工程'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除这条记录？'),
        content: const Text('只移除工程记录，不会删除原始素材或已保存的视频。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除记录'),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.removeCompletedJourney(journey);
  }

  Future<void> _showDetails(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TripColors.paper,
    builder: (_) => _JourneyDetailsSheet(state: state, journey: journey),
  );
}

class _JourneyDetailsSheet extends StatelessWidget {
  const _JourneyDetailsSheet({required this.state, required this.journey});

  final AppState state;
  final CompletedJourney journey;

  @override
  Widget build(BuildContext context) {
    final template = journey.selectedTemplate;
    final missing = state.missingJourneyAssets[journey.id] ?? const <String>[];
    final editable = missing.isEmpty;
    final musicName =
        journey.musicTitle ??
        (template?.plan.musicId == 'local'
            ? journey.localMusicName ?? '本地音乐'
            : MusicCatalog.byId(template?.plan.musicId ?? '').title);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      maxChildSize: .95,
      minChildSize: .55,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFB9AD9D),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(journey.title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '${journey.assets.length} 个素材 · ${(journey.durationMs / 1000).toStringAsFixed(0)} 秒 · $musicName',
            style: const TextStyle(color: Color(0xFF6E645A)),
          ),
          if (state.availableJourneyOutputs.contains(journey.id) &&
              journey.renderedPath != null) ...[
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: buildRenderedVideoPreview(journey.renderedPath!),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text('使用的素材', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final asset in journey.assets)
                Chip(
                  avatar: Icon(
                    missing.contains(asset.name)
                        ? Icons.link_off
                        : asset.kind == MediaKind.image
                        ? Icons.image_outlined
                        : Icons.videocam_outlined,
                    size: 18,
                  ),
                  label: Text(asset.name),
                  side: BorderSide(
                    color: missing.contains(asset.name)
                        ? TripColors.danger
                        : const Color(0xFFCFC2B1),
                  ),
                ),
            ],
          ),
          if (template != null) ...[
            const SizedBox(height: 22),
            Text('模板与剪辑思路', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${template.name} · ${template.description}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(template.rationale),
          ],
          if (journey.userBrief.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('上次修改要求', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(journey.userBrief),
          ],
          const SizedBox(height: 24),
          if (!editable)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7DF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                kIsWeb
                    ? '浏览器未保留原始文件权限，当前只能查看工程信息。重新选择原素材后可开始新的创作。'
                    : '有 ${missing.length} 个原始文件已移动或删除，当前只能查看工程信息。',
                style: const TextStyle(
                  color: TripColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: editable
                ? () async {
                    Navigator.pop(context);
                    await state.openCompletedJourney(journey);
                  }
                : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('继续剪辑'),
          ),
        ],
      ),
    );
  }
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            28,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            80,
          ),
          sliver: SliverList.list(
            children: [
              const _PageHeader(
                eyebrow: 'TRIPWEAVE · LOCAL STUDIO',
                title: '把旅行素材，\n剪成一段好看的视频。',
                description: '导入照片与视频，旅织会自动优化人像、寻找节奏，并生成一支可以继续编辑的旅行 Vlog。',
              ),
              const SizedBox(height: 32),
              _JourneyHero(state: state),
              const SizedBox(height: 34),
              _StatsRow(state: state),
              const SizedBox(height: 48),
              _SectionHeading(
                index: '01',
                title: '这次旅程',
                actionLabel: state.assets.isEmpty ? null : '管理素材',
                onAction: state.assets.isEmpty
                    ? null
                    : () => state.goToCreationStep(CreationStep.curate),
              ),
              const SizedBox(height: 18),
              _RecentMedia(state: state),
              const SizedBox(height: 50),
              const _SectionHeading(index: '02', title: '自动工作流'),
              const SizedBox(height: 18),
              _Workflow(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
                color: TripColors.paprikaDark,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style:
                  (wide
                          ? Theme.of(context).textTheme.displayLarge
                          : Theme.of(context).textTheme.displayMedium)
                      ?.copyWith(fontSize: wide ? 62 : 42),
            ),
          ],
        );
        final copy = Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF62594F)),
          maxLines: 4,
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 18), copy],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 7, child: heading),
            const SizedBox(width: 56),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: copy,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Container(
          height: compact ? 430 : 390,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: TripColors.indigo,
            borderRadius: BorderRadius.circular(compact ? 28 : 38),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _RoutePainter()),
              ),
              Positioned(
                left: compact ? 24 : 42,
                top: compact ? 28 : 38,
                right: compact ? 24 : null,
                child: SizedBox(
                  width: compact ? null : 340,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LightLabel(
                        icon: Icons.lock_outline,
                        text: '原片留在设备上',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        state.assets.isEmpty
                            ? '从第一张照片\n开始织旅程'
                            : '${state.assets.length} 个片段\n正在等待成片',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: const Color(0xFFF7EEDF),
                              fontSize: compact ? 31 : 39,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        state.assets.isEmpty
                            ? '支持 JPG、PNG、WebP、HEIC、MP4、MOV 与 WebM。'
                            : '照片自动自然美化，视频参与节奏编排。你始终可以保留或恢复原片。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFD8DFDD),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: state.isImporting
                                ? null
                                : state.importMedia,
                            icon: state.isImporting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: TripColors.paper,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                            label: Text(
                              state.isImporting ? '正在导入…' : '导入照片与视频',
                            ),
                          ),
                          if (state.assets.length >= 2)
                            OutlinedButton.icon(
                              onPressed: state.isGenerating
                                  ? null
                                  : () => state.generateVlog(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: TripColors.paper,
                                side: const BorderSide(
                                  color: Color(0x99F6F0E5),
                                ),
                              ),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('生成 Vlog'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!compact)
                Positioned(
                  right: 55,
                  top: 34,
                  bottom: 26,
                  width: math.min(420, constraints.maxWidth * .39),
                  child: _HeroCollage(assets: state.assets),
                )
              else
                Positioned(
                  right: -22,
                  bottom: -48,
                  width: 218,
                  height: 178,
                  child: IgnorePointer(
                    child: _HeroCollage(assets: state.assets),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCollage extends StatelessWidget {
  const _HeroCollage({required this.assets});
  final List<MediaItem> assets;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 34,
          width: 180,
          height: 238,
          child: Transform.rotate(
            angle: -.075,
            child: _Polaroid(
              asset: assets.isNotEmpty ? assets[0] : null,
              tone: TripColors.sun,
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          width: 168,
          height: 218,
          child: Transform.rotate(
            angle: .065,
            child: _Polaroid(
              asset: assets.length > 1 ? assets[1] : null,
              tone: TripColors.moss,
            ),
          ),
        ),
        Positioned(
          right: 38,
          bottom: 0,
          width: 155,
          height: 180,
          child: Transform.rotate(
            angle: -.02,
            child: _Polaroid(
              asset: assets.length > 2 ? assets[2] : null,
              tone: TripColors.paprika,
            ),
          ),
        ),
      ],
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.asset, required this.tone});
  final MediaItem? asset;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F2E6),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B1116),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: _MediaVisual(asset: asset, fallback: tone),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x153CD0C4)
      ..strokeWidth = 1;
    for (double x = 24; x < size.width; x += 52) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 24; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final route = Path()
      ..moveTo(size.width * .38, size.height * .9)
      ..cubicTo(
        size.width * .48,
        size.height * .62,
        size.width * .62,
        size.height * .78,
        size.width * .68,
        size.height * .45,
      )
      ..cubicTo(
        size.width * .73,
        size.height * .18,
        size.width * .89,
        size.height * .34,
        size.width * .95,
        size.height * .08,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0x99F0B552)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .45),
      6,
      Paint()..color = TripColors.sun,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LightLabel extends StatelessWidget {
  const _LightLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: TripColors.sun),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFECE7DD),
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('照片', '${state.imageCount}', Icons.photo_outlined),
      ('视频', '${state.videoCount}', Icons.videocam_outlined),
      ('已美化', '${state.enhancedCount}', Icons.face_retouching_natural),
      (
        '成片时长',
        state.draft == null ? '—' : '${state.draft!.totalDuration.inSeconds}s',
        Icons.timelapse,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 4;
        return Wrap(
          spacing: 0,
          runSpacing: 18,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: constraints.maxWidth / columns,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: i % columns == 0
                        ? null
                        : const Border(
                            left: BorderSide(color: Color(0xFFD2C5B5)),
                          ),
                  ),
                  child: Row(
                    children: [
                      Icon(items[i].$3, size: 21, color: TripColors.paprika),
                      const SizedBox(width: 11),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].$2,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            items[i].$1,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF71675D)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.index,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String index;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TripColors.paprika),
          ),
          alignment: Alignment.center,
          child: Text(
            index,
            style: const TextStyle(
              fontSize: 11,
              color: TripColors.paprikaDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _RecentMedia extends StatelessWidget {
  const _RecentMedia({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.assets.isEmpty) {
      return InkWell(
        onTap: state.importMedia,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: TripColors.paperDeep,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: 34,
                color: TripColors.paprika,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '还没有旅行素材',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text('导入几张照片或一段视频，自动工作流就会从这里开始。'),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: math.min(state.assets.length, 8),
        separatorBuilder: (_, _) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          final asset = state.assets[index];
          return SizedBox(
            width: index == 0 ? 242 : 154,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _MediaVisual(
                    asset: asset,
                    fallback: index.isEven ? TripColors.moss : TripColors.sun,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA1F1B17)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 13,
                    right: 10,
                    bottom: 11,
                    child: Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TripColors.paper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (asset.kind == MediaKind.video)
                    const Center(
                      child: CircleAvatar(
                        backgroundColor: Color(0xCCF6F0E5),
                        child: Icon(Icons.play_arrow, color: TripColors.ink),
                      ),
                    ),
                  if (asset.isEnhanced)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: _Badge(text: '已美化', color: TripColors.moss),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Workflow extends StatelessWidget {
  const _Workflow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('A', '分析素材', '识别照片与视频，保留时间顺序和画面比例。', state.assets.isNotEmpty),
      ('B', '自然美化', '肤色区域柔化，同时优化光线、对比度和色彩。', state.enhancedCount > 0),
      ('C', '编排节奏', '自动分配时长、字幕、转场和音乐气质。', state.draft != null),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720;
        final cards = [
          for (final step in steps)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: horizontal && step != steps.last ? 28 : 0,
                  bottom: horizontal ? 0 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          step.$1,
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 38,
                            color: TripColors.paprika,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Divider(
                            color: step.$4
                                ? TripColors.paprika
                                : const Color(0xFFCFC2B2),
                          ),
                        ),
                        if (step.$4)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle,
                              size: 20,
                              color: TripColors.success,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.$2,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      step.$3,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B6258),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ];
        return horizontal
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards)
            : Column(children: cards);
      },
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String filter = '全部';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final filtered = state.assets.where((asset) {
      return switch (filter) {
        '照片' => asset.kind == MediaKind.image,
        '视频' => asset.kind == MediaKind.video,
        '已美化' => asset.isEnhanced,
        _ => true,
      };
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            30,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            18,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '素材选择',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w800,
                              color: TripColors.paprikaDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '选择要放入视频的素材',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.isImporting ? null : state.importMedia,
                      icon: const Icon(Icons.add),
                      label: const Text('继续批量导入'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _BeautyPanel(state: state),
                const SizedBox(height: 25),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final label in ['全部', '照片', '视频', '已美化']) ...[
                        ChoiceChip(
                          label: Text(label),
                          selected: filter == label,
                          onSelected: (_) => setState(() => filter = label),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '已选择 ${state.selectedCount} / ${state.assets.length}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: state.selectedCount == state.assets.length
                            ? state.clearAssetSelection
                            : state.selectAllAssets,
                        child: Text(
                          state.selectedCount == state.assets.length
                              ? '取消全选'
                              : '全选',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _LibraryEmpty(onImport: state.importMedia),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
              8,
              MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
              90,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 330,
                mainAxisExtent: 300,
                crossAxisSpacing: 16,
                mainAxisSpacing: 18,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _MediaCard(asset: filtered[index], state: state),
            ),
          ),
      ],
    );
  }
}

class _BeautyPanel extends StatelessWidget {
  const _BeautyPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: TripColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 670;
          final copy = Row(
            children: [
              const CircleAvatar(
                backgroundColor: TripColors.sun,
                foregroundColor: TripColors.ink,
                child: Icon(Icons.face_retouching_natural),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '人像优化',
                      style: TextStyle(
                        color: TripColors.paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '强度 ${state.globalBeautyLevel < .4
                          ? '轻柔'
                          : state.globalBeautyLevel < .75
                          ? '自然'
                          : '明亮'} · 只处理已选择照片',
                      style: const TextStyle(
                        color: Color(0xFFCFC8BD),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final presets = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in BeautyPreset.values)
                ChoiceChip(
                  label: Text(switch (preset) {
                    BeautyPreset.natural => '自然美颜',
                    BeautyPreset.smooth => '细致磨皮',
                    BeautyPreset.bright => '清透提亮',
                    BeautyPreset.slim => '轻量塑形',
                  }),
                  selected: state.beautyPreset == preset,
                  onSelected: state.isEnhancing
                      ? null
                      : (_) => state.setBeautyPreset(preset),
                  selectedColor: TripColors.sun,
                  backgroundColor: TripColors.indigo,
                  labelStyle: TextStyle(
                    color: state.beautyPreset == preset
                        ? TripColors.ink
                        : TripColors.paper,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide.none,
                ),
            ],
          );
          final controls = Row(
            children: [
              Expanded(
                child: Slider(
                  value: state.globalBeautyLevel,
                  onChanged: state.isEnhancing ? null : state.setBeautyLevel,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: state.isEnhancing ? null : state.enhanceAll,
                icon: state.isEnhancing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(state.isEnhancing ? '美化中…' : '自动美化'),
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 16),
              presets,
              SizedBox(height: compact ? 12 : 8),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.asset, required this.state});
  final MediaItem asset;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: asset.selected,
      label: '${asset.kind == MediaKind.image ? '照片' : '视频'} ${asset.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _MediaVisual(
                    asset: asset,
                    fallback: TripColors.indigo,
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: InkWell(
                    onTap: () => state.toggleSelection(asset),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: asset.selected
                            ? TripColors.paprika
                            : const Color(0xDDF6F0E5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        asset.selected ? Icons.check : Icons.add,
                        color: asset.selected
                            ? TripColors.paper
                            : TripColors.ink,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _MediaMenu(asset: asset, state: state),
                ),
                if (asset.kind == MediaKind.video)
                  const Center(
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xDDF6F0E5),
                      child: Icon(
                        Icons.play_arrow,
                        color: TripColors.ink,
                        size: 29,
                      ),
                    ),
                  ),
                if (asset.status == ProcessingStatus.processing ||
                    asset.status == ProcessingStatus.queued)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xAA27231F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: TripColors.sun,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            asset.status == ProcessingStatus.queued
                                ? '等待处理'
                                : '正在自然美化',
                            style: const TextStyle(
                              color: TripColors.paper,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (asset.isEnhanced)
                  const Positioned(
                    left: 10,
                    bottom: 10,
                    child: _Badge(text: '自然美化', color: TripColors.moss),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            asset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            '${asset.kind == MediaKind.image ? '照片' : '视频'} · ${asset.sizeLabel}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF756B60)),
          ),
        ],
      ),
    );
  }
}

class _MediaMenu extends StatelessWidget {
  const _MediaMenu({required this.asset, required this.state});
  final MediaItem asset;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '素材操作',
      color: TripColors.paper,
      icon: const CircleAvatar(
        radius: 19,
        backgroundColor: Color(0xDDF6F0E5),
        child: Icon(Icons.more_horiz, color: TripColors.ink),
      ),
      onSelected: (value) {
        if (value == 'restore') state.restoreOriginal(asset);
        if (value == 'remove') state.removeAsset(asset);
      },
      itemBuilder: (_) => [
        if (asset.isEnhanced)
          const PopupMenuItem(value: 'restore', child: Text('恢复原片')),
        const PopupMenuItem(value: 'remove', child: Text('从旅程移除')),
      ],
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 62,
              color: TripColors.paprika,
            ),
            const SizedBox(height: 18),
            Text(
              '这里还没有可用素材',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('导入照片与视频，选择想放进故事的片段。'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('导入第一批素材'),
            ),
          ],
        ),
      ),
    );
  }
}

class VlogPage extends StatefulWidget {
  const VlogPage({super.key});

  @override
  State<VlogPage> createState() => _VlogPageState();
}

class _VlogPageState extends State<VlogPage> {
  final titleController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            30,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
            90,
          ),
          sliver: SliverList.list(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VLOG CUT',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w800,
                            color: TripColors.paprikaDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.agentResult != null
                              ? '成片已经准备好'
                              : state.agentTemplates.isNotEmpty
                              ? '选择一个故事方向'
                              : '分析素材并生成模板',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  if (state.agentResult?.renderedPath != null)
                    OutlinedButton.icon(
                      onPressed: state.saveRenderedVideo,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('保存 MP4'),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              _AgentStudio(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentStudio extends StatelessWidget {
  const _AgentStudio({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedAgentTemplate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!state.visionConfig.isReady) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TripColors.sun.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TripColors.sun),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_outlined, color: TripColors.ink),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '需要剪辑服务配置码',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 3),
                      Text('向运营人员领取 8 位一次性码，不需要自己填写模型地址或密钥。'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => state.goTo(2),
                  child: const Text('去配置'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TripColors.indigo,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LightLabel(
                        icon: Icons.psychology_alt_outlined,
                        text: 'VISION + TOOLS + FFMPEG',
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '批量分析，一次给出三个模板',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: TripColors.paper),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.selectedCount} 个已选素材 · 只上传压缩预览，原始文件与最终视频留在本机。',
                        style: const TextStyle(
                          color: Color(0xFFD3DAD7),
                          height: 1.55,
                        ),
                      ),
                    ],
                  );
                  final action = FilledButton.icon(
                    onPressed: state.isAgentAnalyzing
                        ? null
                        : state.visionConfig.isReady
                        ? state.analyzeWithEditingAgent
                        : () => state.goTo(2),
                    icon: state.isAgentAnalyzing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      state.isAgentAnalyzing
                          ? '正在分析…'
                          : !state.visionConfig.isReady
                          ? '输入配置码'
                          : state.agentTemplates.isEmpty
                          ? '分析并生成模板'
                          : '按剪辑思路重新生成',
                    ),
                  );
                  if (constraints.maxWidth >= 720) {
                    return Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 30),
                        action,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 20), action],
                  );
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                initialValue: state.agentUserBrief,
                onChanged: state.setAgentUserBrief,
                maxLines: 2,
                style: const TextStyle(color: TripColors.paper),
                decoration: const InputDecoration(
                  labelText: '你的剪辑思路（可选）',
                  hintText: '例如：多保留人物互动，节奏慢一点，少用空镜。',
                  labelStyle: TextStyle(color: Color(0xFFD3DAD7)),
                  hintStyle: TextStyle(color: Color(0xFF9FACA9)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF85928F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: TripColors.sun, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state.agentEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AgentActivity(events: state.agentEvents),
        ],
        if (state.agentTemplates.isNotEmpty) ...[
          const SizedBox(height: 36),
          const _SectionHeading(index: '01', title: '选择剪辑模板'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 920
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 580
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final template in state.agentTemplates)
                    SizedBox(
                      width: cardWidth,
                      child: _AgentTemplateCard(
                        template: template,
                        selected: template.id == state.selectedAgentTemplateId,
                        onTap: () => state.selectAgentTemplate(template.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        if (selected != null) ...[
          const SizedBox(height: 40),
          const _SectionHeading(index: '02', title: '预览并生成视频'),
          const SizedBox(height: 18),
          _AgentTemplatePreview(state: state, template: selected),
          const SizedBox(height: 24),
          _SimpleClipEditor(state: state, template: selected),
        ],
      ],
    );
  }
}

class _AgentActivity extends StatelessWidget {
  const _AgentActivity({required this.events});
  final List<AgentEvent> events;

  @override
  Widget build(BuildContext context) {
    final visible = events.length > 5
        ? events.sublist(events.length - 5)
        : events;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: TripColors.paperDeep,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final event in visible)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    switch (event.kind) {
                      AgentEventKind.thought => Icons.visibility_outlined,
                      AgentEventKind.action => Icons.build_circle_outlined,
                      AgentEventKind.observation => Icons.fact_check_outlined,
                      AgentEventKind.completed => Icons.check_circle_outline,
                      AgentEventKind.error => Icons.error_outline,
                    },
                    size: 18,
                    color: event.kind == AgentEventKind.completed
                        ? TripColors.success
                        : TripColors.paprika,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      event.message,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AgentTemplateCard extends StatelessWidget {
  const _AgentTemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final AgentTemplateProposal template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '剪辑模板 ${template.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            color: selected ? TripColors.ink : TripColors.paperDeep,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? TripColors.sun : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _Badge(
                      text: template.accent,
                      color: selected ? TripColors.paprika : TripColors.moss,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? TripColors.sun : TripColors.moss,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: selected ? TripColors.paper : TripColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                template.description,
                style: TextStyle(
                  height: 1.5,
                  color: selected
                      ? const Color(0xFFD3CEC5)
                      : const Color(0xFF6E645A),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${template.plan.clips.length} 个片段 · ${(template.plan.totalDurationMs / 1000).toStringAsFixed(0)} 秒 · ${switch (template.plan.ratio) {
                  VlogRatio.portrait => '9:16',
                  VlogRatio.landscape => '16:9',
                  VlogRatio.square => '1:1',
                }}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? TripColors.sun : TripColors.paprikaDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentTemplatePreview extends StatelessWidget {
  const _AgentTemplatePreview({required this.state, required this.template});
  final AppState state;
  final AgentTemplateProposal template;

  @override
  Widget build(BuildContext context) {
    final selectedMusic = template.plan.musicId == 'local'
        ? null
        : MusicCatalog.byId(template.plan.musicId);
    final draft = VlogDraft(
      title: template.plan.title,
      subtitle: template.description,
      style: VlogStyle.postcard,
      ratio: template.plan.ratio,
      music: selectedMusic?.title ?? state.localMusicName ?? '本地音乐',
      clips: [
        for (final clip in template.plan.clips)
          VlogClip(
            mediaId: clip.mediaId,
            duration: Duration(milliseconds: clip.durationMs),
            caption: clip.caption,
            transition: '柔和转场',
          ),
      ],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        template.id.hashCode.abs(),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE8DDCB),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewWidth = math.min(
            constraints.maxWidth,
            switch (template.plan.ratio) {
              VlogRatio.landscape => 540.0,
              VlogRatio.square => 320.0,
              VlogRatio.portrait => 180.0,
            },
          );
          final preview = Center(
            child: SizedBox(
              width: previewWidth,
              child: state.agentResult?.renderedPath != null
                  ? buildRenderedVideoPreview(state.agentResult!.renderedPath!)
                  : VlogPreview(draft: draft, assets: state.assets),
            ),
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.plan.title,
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(color: TripColors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                template.description,
                style: const TextStyle(color: Color(0xFF6E645A), height: 1.55),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TripColors.paper,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '剪辑思路',
                      style: TextStyle(
                        fontSize: 11,
                        color: TripColors.paprikaDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.rationale,
                      style: const TextStyle(
                        color: TripColors.ink,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _DetailLine(
                icon: Icons.movie_filter_outlined,
                label: '片段',
                value: '${template.plan.clips.length} 个',
              ),
              _DetailLine(
                icon: Icons.timelapse,
                label: '时长',
                value:
                    '${(template.plan.totalDurationMs / 1000).toStringAsFixed(1)} 秒',
              ),
              _DetailLine(
                icon: Icons.memory,
                label: '执行',
                value: '硬件优先 · FFmpeg / WebCodecs',
              ),
              _DetailLine(
                icon: Icons.music_note,
                label: '音乐',
                value: selectedMusic == null
                    ? state.localMusicName ?? '本地音乐'
                    : '${selectedMusic.title} · ${selectedMusic.license}',
              ),
              _DetailLine(
                icon: Icons.graphic_eq,
                label: '预览声音',
                value: state.agentResult?.renderedPath == null
                    ? '生成后同步播放素材原声 + 背景音乐'
                    : '素材原声 + 背景音乐已同步混音',
              ),
              const SizedBox(height: 18),
              if (state.isAgentRendering) ...[
                LinearProgressIndicator(
                  value: state.agentRenderProgress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  color: TripColors.paprika,
                  backgroundColor: const Color(0xFFCFC2B1),
                ),
                const SizedBox(height: 7),
                Text(
                  '正在编码（硬件优先） ${(state.agentRenderProgress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6E645A),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (state.agentResult?.renderedPath != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E3D7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_outlined, color: TripColors.success),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '硬件优先导出与 FFprobe 验证均已通过。',
                          style: TextStyle(
                            color: TripColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: state.isAgentRendering
                        ? null
                        : state.renderSelectedAgentTemplate,
                    icon: state.isAgentRendering
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.movie_creation_outlined),
                    label: Text(
                      state.isAgentRendering
                          ? '正在生成…'
                          : state.agentResult?.renderedPath == null
                          ? '生成带声音预览'
                          : '重新生成带声音预览',
                    ),
                  ),
                  if (state.agentResult?.renderedPath != null)
                    OutlinedButton.icon(
                      onPressed: state.saveRenderedVideo,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('保存 MP4'),
                    ),
                ],
              ),
            ],
          );
          if (constraints.maxWidth >= 800) {
            return Row(
              children: [
                Expanded(flex: 5, child: preview),
                const SizedBox(width: 42),
                Expanded(flex: 4, child: actions),
              ],
            );
          }
          return Column(
            children: [preview, const SizedBox(height: 28), actions],
          );
        },
      ),
    );
  }
}

class _SimpleClipEditor extends StatelessWidget {
  const _SimpleClipEditor({required this.state, required this.template});
  final AppState state;
  final AgentTemplateProposal template;

  @override
  Widget build(BuildContext context) {
    final assetById = {for (final asset in state.assets) asset.id: asset};
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: TripColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.linear_scale, color: TripColors.sun),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  '成片轨道',
                  style: TextStyle(
                    color: TripColors.paper,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '点击片段选择需要的区间',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCFC8BD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 144,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: template.plan.clips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final clip = template.plan.clips[index];
                final asset = assetById[clip.mediaId];
                if (asset == null) return const SizedBox.shrink();
                return SizedBox(
                  width: 164,
                  child: InkWell(
                    onTap: () => _openTrimSheet(
                      context,
                      state: state,
                      asset: asset,
                      clip: clip,
                      clipIndex: index,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _MediaVisual(
                                  asset: asset,
                                  fallback: index.isEven
                                      ? TripColors.moss
                                      : TripColors.indigo,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0xAA27231F),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 9,
                                  bottom: 7,
                                  child: Text(
                                    asset.kind == MediaKind.video
                                        ? '${(clip.startMs / 1000).toStringAsFixed(1)}s → ${((clip.startMs + clip.durationMs) / 1000).toStringAsFixed(1)}s'
                                        : '停留 ${(clip.durationMs / 1000).toStringAsFixed(1)}s',
                                    style: const TextStyle(
                                      color: TripColors.paper,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${index + 1}. ${asset.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TripColors.paper,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTrimSheet(
    BuildContext context, {
    required AppState state,
    required MediaItem asset,
    required AgentClipPlan clip,
    required int clipIndex,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TripColors.paper,
      builder: (_) => _ClipTrimSheet(
        state: state,
        asset: asset,
        clip: clip,
        clipIndex: clipIndex,
      ),
    );
  }
}

class _ClipTrimSheet extends StatefulWidget {
  const _ClipTrimSheet({
    required this.state,
    required this.asset,
    required this.clip,
    required this.clipIndex,
  });

  final AppState state;
  final MediaItem asset;
  final AgentClipPlan clip;
  final int clipIndex;

  @override
  State<_ClipTrimSheet> createState() => _ClipTrimSheetState();
}

class _ClipTrimSheetState extends State<_ClipTrimSheet> {
  late RangeValues videoRange;
  late double photoDuration;

  @override
  void initState() {
    super.initState();
    videoRange = RangeValues(
      widget.clip.startMs / 1000,
      (widget.clip.startMs + widget.clip.durationMs) / 1000,
    );
    photoDuration = widget.clip.durationMs / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.asset.kind == MediaKind.video;
    final maxSeconds = math.max(30.0, videoRange.end + 10);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFB9AD9D),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.asset.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            video ? '拖动两端，选择视频中要保留的区间。' : '选择这张照片在成片中停留多久。',
            style: const TextStyle(color: Color(0xFF6E645A)),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 16 / 7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _MediaVisual(
                asset: widget.asset,
                fallback: TripColors.indigo,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (video) ...[
            Container(
              height: 72,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TripColors.paprika, width: 2),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: Opacity(
                        opacity: i.isEven ? .88 : .66,
                        child: _MediaVisual(
                          asset: widget.asset,
                          fallback: TripColors.indigo,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            RangeSlider(
              min: 0,
              max: maxSeconds,
              divisions: (maxSeconds * 2).round(),
              values: videoRange,
              labels: RangeLabels(
                '${videoRange.start.toStringAsFixed(1)} 秒',
                '${videoRange.end.toStringAsFixed(1)} 秒',
              ),
              onChanged: (value) {
                if (value.end - value.start < 1.2) return;
                if (value.end - value.start > 8) return;
                setState(() => videoRange = value);
              },
            ),
            Text(
              '使用 ${videoRange.start.toStringAsFixed(1)}–${videoRange.end.toStringAsFixed(1)} 秒，共 ${(videoRange.end - videoRange.start).toStringAsFixed(1)} 秒',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ] else ...[
            Slider(
              min: 1.2,
              max: 8,
              divisions: 34,
              value: photoDuration.clamp(1.2, 8),
              label: '${photoDuration.toStringAsFixed(1)} 秒',
              onChanged: (value) => setState(() => photoDuration = value),
            ),
            Text(
              '照片停留 ${photoDuration.toStringAsFixed(1)} 秒',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.state.removeAgentClip(widget.clipIndex);
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('移出成片'),
              ),
              OutlinedButton.icon(
                onPressed: _chooseReplacement,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('替换素材'),
              ),
              FilledButton(
                onPressed: () {
                  widget.state.setAgentClipRange(
                    index: widget.clipIndex,
                    startMs: video ? (videoRange.start * 1000).round() : 0,
                    durationMs: video
                        ? ((videoRange.end - videoRange.start) * 1000).round()
                        : (photoDuration * 1000).round(),
                  );
                  Navigator.pop(context);
                },
                child: const Text('应用片段'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseReplacement() async {
    final replacement = await showModalBottomSheet<MediaItem>(
      context: context,
      useSafeArea: true,
      backgroundColor: TripColors.paper,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择替换素材', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('新素材会保留当前片段时长，视频从开头开始。'),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: widget.state.assets.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, index) {
                  final asset = widget.state.assets[index];
                  return ListTile(
                    onTap: () => Navigator.pop(sheetContext, asset),
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox.square(
                      dimension: 52,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _MediaVisual(
                          asset: asset,
                          fallback: TripColors.indigo,
                        ),
                      ),
                    ),
                    title: Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(asset.kind == MediaKind.image ? '照片' : '视频'),
                    trailing: asset.id == widget.asset.id
                        ? const Icon(
                            Icons.check_circle,
                            color: TripColors.success,
                          )
                        : const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (replacement == null || !mounted) return;
    widget.state.replaceAgentClip(widget.clipIndex, replacement);
    Navigator.pop(context);
  }
}

// Legacy deterministic editor retained as a local fallback path.
// ignore: unused_element
class _VlogControls extends StatelessWidget {
  const _VlogControls({required this.state, required this.titleController});
  final AppState state;
  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TripColors.paperDeep,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '片名',
                hintText: '例如：海边的三天',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          _LabeledControl(
            label: '风格',
            child: SegmentedButton<VlogStyle>(
              segments: const [
                ButtonSegment(value: VlogStyle.postcard, label: Text('明信片')),
                ButtonSegment(value: VlogStyle.cinema, label: Text('电影感')),
                ButtonSegment(value: VlogStyle.journal, label: Text('手帐')),
              ],
              selected: {state.vlogStyle},
              onSelectionChanged: (value) => state.setStyle(value.first),
            ),
          ),
          _LabeledControl(
            label: '画幅',
            child: SegmentedButton<VlogRatio>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: VlogRatio.portrait, label: Text('9:16')),
                ButtonSegment(value: VlogRatio.landscape, label: Text('16:9')),
                ButtonSegment(value: VlogRatio.square, label: Text('1:1')),
              ],
              selected: {state.vlogRatio},
              onSelectionChanged: (value) => state.setRatio(value.first),
            ),
          ),
          FilledButton.icon(
            onPressed: state.isGenerating
                ? null
                : () => state.generateVlog(title: titleController.text),
            icon: state.isGenerating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              state.isGenerating
                  ? '正在编排…'
                  : state.draft == null
                  ? '生成 Vlog'
                  : '重新生成',
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

// ignore: unused_element
class _VlogEmpty extends StatelessWidget {
  const _VlogEmpty({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 390),
      decoration: BoxDecoration(
        color: TripColors.indigo,
        borderRadius: BorderRadius.circular(30),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.movie_filter_outlined,
            size: 68,
            color: TripColors.sun,
          ),
          const SizedBox(height: 20),
          Text(
            state.assets.length < 2
                ? '先准备至少两个旅行片段'
                : '${state.selectedCount} 个片段已经就位',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: TripColors.paper),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 9),
          Text(
            state.assets.length < 2
                ? '照片、短视频都可以。素材越丰富，自动节奏越自然。'
                : '选择风格和画幅，然后让旅织完成第一版剪辑。',
            style: const TextStyle(color: Color(0xFFD4DCD8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          if (state.assets.length < 2)
            OutlinedButton.icon(
              onPressed: state.importMedia,
              style: OutlinedButton.styleFrom(
                foregroundColor: TripColors.paper,
                side: const BorderSide(color: TripColors.paper),
              ),
              icon: const Icon(Icons.add),
              label: const Text('继续导入素材'),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _VlogWorkspace extends StatelessWidget {
  const _VlogWorkspace({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final preview = Center(
          child: VlogPreview(draft: draft, assets: state.assets),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Badge(text: 'AUTO CUT · READY', color: TripColors.paprika),
            const SizedBox(height: 18),
            Text(draft.title, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 10),
            Text(
              draft.subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6E645A)),
            ),
            const SizedBox(height: 28),
            _DetailLine(
              icon: Icons.music_note,
              label: '配乐',
              value: draft.music,
            ),
            _DetailLine(
              icon: Icons.timelapse,
              label: '时长',
              value: '${draft.totalDuration.inSeconds} 秒',
            ),
            _DetailLine(
              icon: Icons.aspect_ratio,
              label: '画幅',
              value: switch (draft.ratio) {
                VlogRatio.portrait => '9:16 竖屏',
                VlogRatio.landscape => '16:9 横屏',
                VlogRatio.square => '1:1 方形',
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '这是不分析画面内容的本地快速模板；如需按素材内容编排并输出 MP4，请使用自动剪辑。',
              style: TextStyle(color: Color(0xFF6E645A), height: 1.55),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: state.exportProject,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出 Vlog 工程'),
                ),
              ],
            ),
          ],
        );
        if (wide) {
          return Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFFE8DDCB),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Expanded(flex: 5, child: preview),
                const SizedBox(width: 48),
                Expanded(flex: 4, child: details),
              ],
            ),
          );
        }
        return Column(children: [preview, const SizedBox(height: 30), details]);
      },
    );
  }
}

class VlogPreview extends StatefulWidget {
  const VlogPreview({super.key, required this.draft, required this.assets});
  final VlogDraft draft;
  final List<MediaItem> assets;

  @override
  State<VlogPreview> createState() => _VlogPreviewState();
}

class _VlogPreviewState extends State<VlogPreview> {
  Timer? timer;
  int index = 0;
  bool playing = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant VlogPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.createdAt != widget.draft.createdAt ||
        oldWidget.draft.totalDuration != widget.draft.totalDuration) {
      index = 0;
      _start();
    }
  }

  void _start() {
    timer?.cancel();
    if (widget.draft.clips.length < 2 || !playing) return;
    final duration = widget.draft.clips[index].duration;
    timer = Timer(duration, () {
      if (!mounted || !playing) return;
      setState(() => index = (index + 1) % widget.draft.clips.length);
      _start();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = switch (widget.draft.ratio) {
      VlogRatio.portrait => 9 / 16,
      VlogRatio.landscape => 16 / 9,
      VlogRatio.square => 1.0,
    };
    final clip =
        widget.draft.clips[index.clamp(0, widget.draft.clips.length - 1)];
    final asset = widget.assets.cast<MediaItem?>().firstWhere(
      (item) => item?.id == clip.mediaId,
      orElse: () => null,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.draft.ratio == VlogRatio.portrait ? 330 : 580,
        maxHeight: widget.draft.ratio == VlogRatio.portrait ? 586 : 430,
      ),
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                key: ValueKey(clip.mediaId),
                child: _MediaVisual(
                  asset: asset,
                  fallback: TripColors.moss,
                  fit: BoxFit.cover,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .5, 1],
                    colors: [
                      Color(0x441E1A17),
                      Colors.transparent,
                      Color(0xC91E1A17),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 18,
                child: Text(
                  '旅织  ·  ${index + 1}/${widget.draft.clips.length}',
                  style: const TextStyle(
                    color: TripColors.paper,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index == 0)
                      Text(
                        widget.draft.title,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          color: TripColors.paper,
                          fontSize: 29,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      clip.caption,
                      style: const TextStyle(
                        color: TripColors.paper,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (index + 1) / widget.draft.clips.length,
                            minHeight: 3,
                            backgroundColor: const Color(0x66F6F0E5),
                            color: TripColors.sun,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: () {
                            setState(() => playing = !playing);
                            _start();
                          },
                          tooltip: playing ? '暂停预览' : '继续预览',
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TripColors.paprika),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF756A5E), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: TripColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _Timeline extends StatelessWidget {
  const _Timeline({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: draft.clips.length,
        separatorBuilder: (_, index) => SizedBox(
          width: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_forward,
                size: 18,
                color: TripColors.paprika,
              ),
              const SizedBox(height: 4),
              Text(
                draft.clips[index].transition,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: Color(0xFF74685C)),
              ),
            ],
          ),
        ),
        itemBuilder: (context, index) {
          final clip = draft.clips[index];
          final asset = state.assets.cast<MediaItem?>().firstWhere(
            (item) => item?.id == clip.mediaId,
            orElse: () => null,
          );
          return SizedBox(
            width: 154,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _MediaVisual(
                      asset: asset,
                      fallback: index.isEven
                          ? TripColors.moss
                          : TripColors.indigo,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${index + 1}. ${clip.caption}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${(clip.duration.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF786D61),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool localOnly = true;
  bool keepOriginals = true;
  bool autoSelect = true;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
        32,
        MediaQuery.sizeOf(context).width < 600 ? 20 : 42,
        90,
      ),
      children: [
        const Text(
          '偏好设置',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
            color: TripColors.paprikaDark,
          ),
        ),
        const SizedBox(height: 8),
        Text('创作方式，由你决定', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 32),
        _AccountCard(state: state),
        const SizedBox(height: 20),
        _SettingsGroup(
          title: '隐私与原片',
          children: [
            SwitchListTile.adaptive(
              value: localOnly,
              onChanged: (value) => setState(() => localOnly = value),
              title: const Text('仅在本机处理'),
              subtitle: const Text('照片和视频不会上传到服务器。'),
            ),
            SwitchListTile.adaptive(
              value: keepOriginals,
              onChanged: (value) => setState(() => keepOriginals = value),
              title: const Text('始终保留原片'),
              subtitle: const Text('美化结果作为副本保存，随时可以恢复。'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (state.modelPresets.isNotEmpty) ...[
          _PresetPickerCard(state: state),
          const SizedBox(height: 20),
        ],
        if (state.identity?.isAdmin == true) ...[
          _ModelPresetAdminCard(state: state),
          const SizedBox(height: 20),
        ],
        const _VisionSettingsCard(),
        const SizedBox(height: 20),
        _SettingsGroup(
          title: '自动剪辑',
          children: [
            SwitchListTile.adaptive(
              value: autoSelect,
              onChanged: (value) => setState(() => autoSelect = value),
              title: const Text('导入后自动选入旅程'),
              subtitle: const Text('新素材默认进入 Vlog 候选时间线。'),
            ),
            ListTile(
              title: const Text('默认人像强度'),
              subtitle: Slider(
                value: state.globalBeautyLevel,
                onChanged: state.setBeautyLevel,
              ),
              trailing: Text(
                '${(state.globalBeautyLevel * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _PrivacyMark(),
        const SizedBox(height: 18),
        const Text(
          'TripWeave 0.1.5 · Flutter 单代码库\nAndroid / Web / Windows / macOS',
          style: TextStyle(color: Color(0xFF776C60), height: 1.6),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final identity = state.identity;
    if (identity == null) return const SizedBox.shrink();
    return Material(
      color: TripColors.paperDeep,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: identity.isAdmin
                  ? TripColors.sun
                  : TripColors.moss,
              child: Text(
                identity.initial,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: identity.isAdmin ? TripColors.ink : TripColors.paper,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          identity.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Badge(
                        text: identity.isAdmin ? '管理员' : '旅行者',
                        color: identity.isAdmin
                            ? TripColors.paprikaDark
                            : TripColors.moss,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '档案只保存在本机，用于署名和恢复创作偏好。',
                    style: TextStyle(fontSize: 13, color: Color(0xFF62594F)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: state.signOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetPickerCard extends StatelessWidget {
  const _PresetPickerCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TripColors.paperDeep,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: TripColors.paprika),
                const SizedBox(width: 8),
                Text('剪辑服务预置', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '由管理员配置好的 AI 剪辑通道，选择即可使用，无需填写接口和密钥。',
              style: TextStyle(fontSize: 13, color: Color(0xFF62594F)),
            ),
            const SizedBox(height: 12),
            for (final preset in state.modelPresets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PresetTile(
                  preset: preset,
                  active: state.activeModelPresetId == preset.id,
                  isDefault: state.defaultModelPresetId == preset.id,
                  onApply: () => state.applyModelPreset(preset),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.active,
    required this.isDefault,
    required this.onApply,
  });

  final ModelPreset preset;
  final bool active;
  final bool isDefault;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFE0CE) : TripColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? TripColors.paprika : const Color(0xFFD8CCBC),
          width: active ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        preset.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      const _Badge(text: '默认', color: TripColors.indigo),
                    ],
                    if (preset.builtIn) ...[
                      const SizedBox(width: 8),
                      const _Badge(text: '部署内置', color: TripColors.moss),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  preset.note.trim().isNotEmpty
                      ? preset.note
                      : '规划：${preset.planningModel}'
                            '${preset.visionModel.trim().isEmpty ? '' : ' · 视觉：${preset.visionModel}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF62594F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          active
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.check_circle, color: TripColors.paprika),
                )
              : FilledButton.tonal(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: TripColors.ink,
                    foregroundColor: TripColors.paper,
                    minimumSize: const Size(64, 40),
                  ),
                  child: const Text('使用'),
                ),
        ],
      ),
    );
  }
}

class _ModelPresetAdminCard extends StatelessWidget {
  const _ModelPresetAdminCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TripColors.ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: TripColors.sun,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '模型预置管理',
                    style: TextStyle(
                      color: TripColors.paper,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _editPreset(context, state, null),
                  style: FilledButton.styleFrom(
                    backgroundColor: TripColors.sun,
                    foregroundColor: TripColors.ink,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('新建预置'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '预置保存在本机，旅行者选择后即可直接使用剪辑服务，密钥不会展示。'
              '设为默认后，新会话会自动启用。',
              style: TextStyle(color: Color(0xFFCFC5B8), height: 1.5),
            ),
            const SizedBox(height: 12),
            if (state.modelPresets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '还没有预置。新建一个，让这台设备上的旅行者免配置使用 AI 剪辑。',
                  style: TextStyle(color: Color(0xFFCFC5B8)),
                ),
              ),
            for (final preset in state.modelPresets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF37322C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    preset.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: TripColors.paper,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (state.defaultModelPresetId ==
                                    preset.id) ...[
                                  const SizedBox(width: 8),
                                  const _Badge(
                                    text: '默认',
                                    color: TripColors.indigo,
                                  ),
                                ],
                                if (preset.builtIn) ...[
                                  const SizedBox(width: 8),
                                  const _Badge(
                                    text: '部署内置',
                                    color: TripColors.moss,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${preset.endpoint}\n规划：${preset.planningModel}'
                              '${preset.visionModel.trim().isEmpty ? '' : ' · 视觉：${preset.visionModel}'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFCFC5B8),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => state.setDefaultModelPreset(
                          state.defaultModelPresetId == preset.id
                              ? null
                              : preset.id,
                        ),
                        tooltip: state.defaultModelPresetId == preset.id
                            ? '取消默认'
                            : '设为默认',
                        icon: Icon(
                          state.defaultModelPresetId == preset.id
                              ? Icons.star
                              : Icons.star_border,
                          color: TripColors.sun,
                        ),
                      ),
                      if (!preset.builtIn) ...[
                        IconButton(
                          onPressed: () => _editPreset(context, state, preset),
                          tooltip: '编辑',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: TripColors.paper,
                          ),
                        ),
                        IconButton(
                          onPressed: () => state.deleteModelPreset(preset.id),
                          tooltip: '删除',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFE39C8B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPreset(
    BuildContext context,
    AppState state,
    ModelPreset? existing,
  ) async {
    final preset = await showDialog<ModelPreset>(
      context: context,
      builder: (context) => _PresetEditorDialog(existing: existing),
    );
    if (preset != null) await state.saveModelPreset(preset);
  }
}

class _PresetEditorDialog extends StatefulWidget {
  const _PresetEditorDialog({this.existing});
  final ModelPreset? existing;

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  late final nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final endpointController = TextEditingController(
    text: widget.existing?.endpoint ?? '',
  );
  late final proxyController = TextEditingController(
    text: widget.existing?.proxyEndpoint ?? '',
  );
  late final planningController = TextEditingController(
    text: widget.existing?.planningModel ?? '',
  );
  late final visionController = TextEditingController(
    text: widget.existing?.visionModel ?? '',
  );
  late final keyController = TextEditingController(
    text: widget.existing?.apiKey ?? '',
  );
  late final noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  bool obscureKey = true;
  String? validationMessage;

  @override
  void dispose() {
    nameController.dispose();
    endpointController.dispose();
    proxyController.dispose();
    planningController.dispose();
    visionController.dispose();
    keyController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新建模型预置' : '编辑模型预置'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameController, '预置名称', '例如：家庭共享通道'),
              _field(
                endpointController,
                '接口地址',
                'https://example.com/v1/chat/completions',
              ),
              _field(proxyController, 'Web CORS 代理（可选）', ''),
              _field(planningController, '规划模型', 'your-planning-model'),
              _field(visionController, '视觉模型（可留空复用规划模型）', ''),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: keyController,
                  obscureText: obscureKey,
                  decoration: InputDecoration(
                    labelText: 'API 密钥',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => obscureKey = !obscureKey),
                      icon: Icon(
                        obscureKey ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
              ),
              _field(noteController, '给旅行者的说明（可选）', '例如：适合 3 分钟以内的短片'),
              if (validationMessage != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    validationMessage!,
                    style: const TextStyle(
                      color: TripColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存预置')),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _save() {
    final preset = ModelPreset(
      id:
          widget.existing?.id ??
          'preset-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      endpoint: endpointController.text.trim(),
      proxyEndpoint: proxyController.text.trim(),
      planningModel: planningController.text.trim(),
      visionModel: visionController.text.trim(),
      apiKey: keyController.text.trim(),
      note: noteController.text.trim(),
    );
    if (preset.name.isEmpty || !preset.isUsable) {
      setState(
        () => validationMessage = '名称、接口地址、规划模型和 API 密钥都需要填写。',
      );
      return;
    }
    Navigator.of(context).pop(preset);
  }
}

class _VisionSettingsCard extends StatefulWidget {
  const _VisionSettingsCard();

  @override
  State<_VisionSettingsCard> createState() => _VisionSettingsCardState();
}

class _VisionSettingsCardState extends State<_VisionSettingsCard> {
  final endpointController = TextEditingController();
  final proxyEndpointController = TextEditingController();
  final planningModelController = TextEditingController();
  final visionModelController = TextEditingController();
  final keyController = TextEditingController();
  bool enabled = false;
  bool initialized = false;
  bool obscureKey = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final config = AppStateScope.of(context).visionConfig;
    endpointController.text = config.endpoint;
    proxyEndpointController.text = config.proxyEndpoint;
    planningModelController.text = config.planningModel;
    visionModelController.text = config.visionModel;
    keyController.text = config.apiKey;
    enabled = config.enabled;
    initialized = true;
  }

  @override
  void dispose() {
    endpointController.dispose();
    proxyEndpointController.dispose();
    planningModelController.dispose();
    visionModelController.dispose();
    keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Material(
      color: TripColors.indigo,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自定义剪辑服务（高级）',
                        style: TextStyle(
                          color: TripColors.paper,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '有管理员预置时无需填写本卡片。可分别配置视觉理解与 ReAct 规划模型；视觉模型留空时复用同一个多模态模型。手动填写的密钥只保留在当前会话内。',
                        style: TextStyle(
                          color: Color(0xFFD3DAD7),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: enabled,
                  activeTrackColor: TripColors.sun,
                  onChanged: (value) => setState(() => enabled = value),
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 18),
              TextField(
                controller: endpointController,
                style: const TextStyle(color: TripColors.paper),
                decoration: const InputDecoration(
                  labelText: '接口地址',
                  hintText: 'https://example.com/v1/chat/completions',
                  labelStyle: TextStyle(color: Color(0xFFD3DAD7)),
                  hintStyle: TextStyle(color: Color(0xFF9FACA9)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF85928F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: TripColors.sun, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proxyEndpointController,
                style: const TextStyle(color: TripColors.paper),
                decoration: const InputDecoration(
                  labelText: 'Web CORS 代理（可选）',
                  hintText: 'https://your-site.example/api/tripweave/llm',
                  helperText: '仅 Web 直连接口被 CORS 拦截时使用；代理不应保存密钥或素材。',
                  helperStyle: TextStyle(color: Color(0xFFB8C3C0)),
                  labelStyle: TextStyle(color: Color(0xFFD3DAD7)),
                  hintStyle: TextStyle(color: Color(0xFF9FACA9)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF85928F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: TripColors.sun, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final planningField = TextField(
                    controller: planningModelController,
                    style: const TextStyle(color: TripColors.paper),
                    decoration: const InputDecoration(
                      labelText: '规划模型',
                      hintText: 'your-planning-model',
                      labelStyle: TextStyle(color: Color(0xFFD3DAD7)),
                      hintStyle: TextStyle(color: Color(0xFF9FACA9)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF85928F)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: TripColors.sun, width: 2),
                      ),
                    ),
                  );
                  final visionField = TextField(
                    controller: visionModelController,
                    style: const TextStyle(color: TripColors.paper),
                    decoration: const InputDecoration(
                      labelText: '视觉模型（可留空）',
                      hintText: 'your-vision-model；留空则复用规划模型',
                      labelStyle: TextStyle(color: Color(0xFFD3DAD7)),
                      hintStyle: TextStyle(color: Color(0xFF9FACA9)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF85928F)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: TripColors.sun, width: 2),
                      ),
                    ),
                  );
                  if (constraints.maxWidth >= 640) {
                    return Row(
                      children: [
                        Expanded(child: planningField),
                        const SizedBox(width: 12),
                        Expanded(child: visionField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      planningField,
                      const SizedBox(height: 12),
                      visionField,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                obscureText: obscureKey,
                style: const TextStyle(color: TripColors.paper),
                decoration: InputDecoration(
                  labelText: 'API 密钥',
                  labelStyle: const TextStyle(color: Color(0xFFD3DAD7)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF85928F)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: TripColors.sun, width: 2),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscureKey = !obscureKey),
                    tooltip: obscureKey ? '显示密钥' : '隐藏密钥',
                    icon: Icon(
                      obscureKey ? Icons.visibility : Icons.visibility_off,
                      color: TripColors.paper,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '只有主动分析素材时，才发送最多 9 张照片组成的压缩联系表和素材元数据；原视频不上传。',
                      style: TextStyle(
                        color: Color(0xFFD3DAD7),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => state.setVisionConfig(
                      VisionLlmConfig(
                        enabled: enabled,
                        endpoint: endpointController.text,
                        proxyEndpoint: proxyEndpointController.text,
                        planningModel: planningModelController.text,
                        visionModel: visionModelController.text,
                        apiKey: keyController.text,
                      ),
                    ),
                    child: const Text('保存本次会话配置'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => state.setVisionConfig(
                  const VisionLlmConfig(enabled: false),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TripColors.paper,
                  side: const BorderSide(color: Color(0xFF9EAAA7)),
                ),
                icon: const Icon(Icons.cloud_off_outlined),
                label: const Text('保持纯本地模式'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TripColors.paperDeep,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _PrivacyMark extends StatelessWidget {
  const _PrivacyMark({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.shield_outlined, size: 20, color: TripColors.moss),
        if (!compact) ...[
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Local-first · 你的旅行，不离开设备',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: TripColors.moss,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaVisual extends StatelessWidget {
  const _MediaVisual({
    required this.asset,
    required this.fallback,
    this.fit = BoxFit.cover,
  });
  final MediaItem? asset;
  final Color fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (asset != null && asset!.kind == MediaKind.image) {
      if (asset!.isEnhanced) {
        return GpuBeautyImage(
          bytes: asset!.bytes,
          preset: asset!.beautyPreset,
          level: asset!.beautyLevel,
        );
      }
      return Image.memory(
        asset!.displayBytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _AbstractTravelFrame(color: fallback),
      );
    }
    return _AbstractTravelFrame(
      color: fallback,
      video: asset?.kind == MediaKind.video,
    );
  }
}

class _AbstractTravelFrame extends StatelessWidget {
  const _AbstractTravelFrame({required this.color, this.video = false});
  final Color color;
  final bool video;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LandscapePainter(color),
      child: Center(
        child: video
            ? const Icon(
                Icons.videocam_outlined,
                color: Color(0xCCF6F0E5),
                size: 42,
              )
            : null,
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .23),
      size.shortestSide * .11,
      Paint()..color = TripColors.sun,
    );
    final far = Path()
      ..moveTo(0, size.height * .67)
      ..quadraticBezierTo(
        size.width * .22,
        size.height * .30,
        size.width * .47,
        size.height * .67,
      )
      ..quadraticBezierTo(
        size.width * .73,
        size.height * .40,
        size.width,
        size.height * .62,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xAA30455B));
    final near = Path()
      ..moveTo(0, size.height * .78)
      ..quadraticBezierTo(
        size.width * .29,
        size.height * .52,
        size.width * .58,
        size.height * .80,
      )
      ..quadraticBezierTo(
        size.width * .80,
        size.height * .60,
        size.width,
        size.height * .72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xCC52644D));
  }

  @override
  bool shouldRepaint(covariant _LandscapePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: TripColors.paper,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .45,
        ),
      ),
    );
  }
}
