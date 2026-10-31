import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/config/model_config.dart';
import '../../core/services/model_manager_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/responsive.dart';
import '../notes/widgets/error_banner.dart';
import 'setup_cubit.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SetupCubit(
        models: GetIt.I<ModelManagerService>(),
        settings: GetIt.I<SettingsService>(),
      )..load(),
      child: const _SetupView(),
    );
  }
}

class _SetupView extends StatefulWidget {
  const _SetupView();

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  late bool _wifiOnly;

  SettingsService get _settings => GetIt.I<SettingsService>();

  @override
  void initState() {
    super.initState();
    _wifiOnly = _settings.wifiOnlyDownloads;
  }

  Future<void> _skip() async {
    final skip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set up later?'),
        content: const Text(
          'You can download the models later from Settings. Until then, '
          'recording and AI note drafting are unavailable. You can still type '
          'a transcript and edit sections manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue without models'),
          ),
        ],
      ),
    );
    if (skip == true && mounted) {
      await _settings.completeOnboarding();
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _useCellular(SetupCubit cubit) async {
    setState(() => _wifiOnly = false);
    await _settings.setWifiOnlyDownloads(false);
    if (mounted) await cubit.install(allowCellular: true);
  }

  Future<void> _finish() async {
    await _settings.completeOnboarding();
    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<SetupCubit, SetupState>(
      builder: (context, state) {
        final cubit = context.read<SetupCubit>();
        final llmReady = state.status?.llmReady ?? false;
        final sttReady = state.status?.sttReady ?? false;
        final complete = state.isComplete;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Set up on-device AI'),
            automaticallyImplyLeading: _settings.hasCompletedOnboarding,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: CenteredContent(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Two models, one download',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The language model drafts clinical notes. The speech '
                      'model transcribes English and Hindi. Both run on this '
                      'device after a one-time download.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ModelTile(
                      icon: Icons.memory_outlined,
                      title: ModelCatalog.llm.displayName,
                      subtitle:
                          '${ModelCatalog.llm.description}\n${ModelCatalog.llm.sizeLabel}',
                      ready: llmReady,
                    ),
                    const SizedBox(height: 10),
                    _ModelTile(
                      icon: Icons.graphic_eq,
                      title: ModelCatalog.stt.displayName,
                      subtitle:
                          '${ModelCatalog.stt.description}\n${ModelCatalog.stt.sizeLabel}',
                      ready: sttReady,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Total download: ${ModelCatalog.totalSizeLabel}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (state.isInstalling) ...[
                      LinearProgressIndicator(
                        value: state.overall > 0 && state.overall < 1
                            ? state.overall
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.progress.message.isEmpty
                                  ? 'Downloading…'
                                  : state.progress.message,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (state.overall > 0)
                            Text(
                              '${(state.overall * 100).round()}%',
                              style: theme.textTheme.labelLarge,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: cubit.cancel,
                        child: const Text('Cancel download'),
                      ),
                    ] else if (state.error != null) ...[
                      ErrorBanner(
                        message: state.error!,
                        onRetry: state.needsWifi ? null : () => cubit.install(),
                      ),
                      if (state.needsWifi) ...[
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: () => _useCellular(cubit),
                          icon: const Icon(Icons.cell_tower),
                          label: const Text('Download over mobile data'),
                        ),
                      ],
                      const SizedBox(height: 10),
                    ],
                    if (!state.isInstalling && !complete)
                      FilledButton.icon(
                        onPressed: state.isChecking
                            ? null
                            : () => cubit.install(),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          state.error == null ? 'Download models' : 'Try again',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    if (complete) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Both models are ready. The app now works '
                                'without internet.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _finish,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Start using the app'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: SwitchListTile(
                        value: _wifiOnly,
                        onChanged: state.isInstalling || complete
                            ? null
                            : (value) async {
                                setState(() => _wifiOnly = value);
                                await _settings.setWifiOnlyDownloads(value);
                              },
                        title: const Text('Wi-Fi only download'),
                        subtitle: const Text(
                          'Recommended for the one-time model download. You can '
                          'change this later in Settings.',
                        ),
                        secondary: const Icon(Icons.wifi),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConfig.privacySummary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Model files are not patient data and are stored '
                      'unencrypted. Your notes remain encrypted.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!complete) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: state.isInstalling ? null : _skip,
                        child: const Text('Skip for now'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ready,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              ready ? Icons.check_circle : Icons.download_for_offline_outlined,
              color: ready
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
