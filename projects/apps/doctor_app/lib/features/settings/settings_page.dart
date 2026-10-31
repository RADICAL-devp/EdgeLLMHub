import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/config/model_config.dart';
import '../../core/data/note_repository.dart';
import '../../core/services/model_manager_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/app_shell.dart';
import '../../core/ui/privacy_dialog.dart';
import '../../core/ui/responsive.dart';
import '../../core/utils/formatters.dart';
import '../notes/widgets/error_banner.dart';
import 'settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        settings: GetIt.I<SettingsService>(),
        models: GetIt.I<ModelManagerService>(),
        repository: GetIt.I<NoteRepository>(),
      )..load(),
      child: const _SettingsScaffold(),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => AppShell(
        title: 'Settings',
        currentIndex: 3,
        child: SettingsView(state: state),
      ),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.state});

  final SettingsState state;

  Future<void> _confirmDeleteModels(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete downloaded models?'),
        content: const Text(
          'Recording and AI drafting will be unavailable until you download the '
          'models again. Your saved notes stay encrypted on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete models'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final cubit = context.read<SettingsCubit>();
    await cubit.deleteModels();
    if (!context.mounted) return;
    if (cubit.state.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloaded models removed.')),
      );
    }
  }

  Future<void> _confirmDeleteNotes(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local notes?'),
        content: const Text(
          'Every saved note will be permanently removed from this device. This '
          'cannot be undone. The downloaded models are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all notes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final cubit = context.read<SettingsCubit>();
    await cubit.deleteAllNotes();
    if (!context.mounted) return;
    if (cubit.state.error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All local notes deleted.')));
    }
  }

  Future<void> _resetOnboarding(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset onboarding and consent?'),
        content: const Text(
          'The welcome and privacy consent screens will appear again. Your '
          'notes and models are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsCubit>().resetOnboarding();
    if (!context.mounted) return;
    context.go(AppRoutes.welcome);
  }

  Future<void> _setThinking(BuildContext context, bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Make thinking mode the default?'),
          content: const Text(AppConfig.thinkingModeWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it off'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await context.read<SettingsCubit>().setThinkingMode(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.isLoading && state.modelStatus == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final modelStatus = state.modelStatus;
    final storageBytes = modelStatus?.storageMb == null
        ? null
        : (modelStatus!.storageMb! * 1024 * 1024).round();

    return RefreshIndicator(
      onRefresh: () => context.read<SettingsCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CenteredContent(
            maxWidth: 780,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Privacy, models, and local data',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This app has no account, cloud sync, or remote clinical '
                  'processing.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(
                    message: state.error!,
                    onRetry: () => context.read<SettingsCubit>().load(),
                  ),
                ],
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'Privacy and security',
                  icon: Icons.shield_outlined,
                  children: [
                    const _InfoRow(
                      icon: Icons.phonelink_lock_outlined,
                      title: 'On-device processing',
                      body:
                          'Audio, transcripts, and notes stay on this device.',
                    ),
                    const _InfoRow(
                      icon: Icons.lock_outline,
                      title: 'Encrypted notes',
                      body:
                          'AES-256-GCM field encryption with a key in the '
                          'platform secure store.',
                    ),
                    const _InfoRow(
                      icon: Icons.delete_outline,
                      title: 'Temporary audio',
                      body:
                          'Deleted immediately after on-device '
                          'transcription.',
                    ),
                    const _InfoRow(
                      icon: Icons.cloud_off_outlined,
                      title: 'Offline by default',
                      body:
                          'Only the one-time model download uses the '
                          'network.',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showPrivacyDetails(context),
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Read privacy details'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  title: 'On-device AI',
                  icon: Icons.memory_outlined,
                  children: [
                    _ModelRow(
                      icon: Icons.memory,
                      title: ModelCatalog.llm.displayName,
                      subtitle: ModelCatalog.llm.sizeLabel,
                      ready: modelStatus?.llmReady ?? false,
                    ),
                    _ModelRow(
                      icon: Icons.graphic_eq,
                      title: ModelCatalog.stt.displayName,
                      subtitle: ModelCatalog.stt.sizeLabel,
                      ready: modelStatus?.sttReady ?? false,
                    ),
                    if (storageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Storage used: ${formatBytes(storageBytes)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.setup),
                          icon: const Icon(Icons.download_for_offline_outlined),
                          label: Text(
                            modelStatus?.allReady == true
                                ? 'Manage models'
                                : 'Set up models',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.isDeletingModels
                              ? null
                              : () => _confirmDeleteModels(context),
                          icon: state.isDeletingModels
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          label: const Text('Delete models'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: state.thinkingMode,
                      onChanged: (value) => _setThinking(context, value),
                      title: const Text('Thinking mode by default'),
                      subtitle: const Text(
                        'Off by default. Takes noticeably longer, but can help '
                        'with complex notes.',
                      ),
                      secondary: const Icon(Icons.psychology_outlined),
                    ),
                    if (state.thinkingMode)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppConfig.thinkingModeWarning,
                          style: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.translate),
                      title: const Text('Default consultation language'),
                      subtitle: const Text(
                        'Used for new notes and speech recognition.',
                      ),
                      trailing: DropdownButton<String>(
                        value: state.languageCode,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final entry
                              in AppConfig.supportedLanguages.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            context.read<SettingsCubit>().setLanguageCode(
                              value,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  title: 'Downloads',
                  icon: Icons.wifi,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: state.wifiOnlyDownloads,
                      onChanged: (value) => context
                          .read<SettingsCubit>()
                          .setWifiOnlyDownloads(value),
                      title: const Text('Wi-Fi only model downloads'),
                      subtitle: const Text(
                        'Recommended for the one-time model download. You can '
                        'turn this off when re-downloading over mobile data.',
                      ),
                    ),
                    Text(
                      'Model downloads happen once. After that, the app works '
                      'without a network connection.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  title: 'Local data',
                  icon: Icons.storage_outlined,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Saved notes'),
                      trailing: Text(
                        '${state.noteCount}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Delete all notes',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      subtitle: const Text(
                        'Notes are permanently removed from this device. '
                        'Models are kept.',
                      ),
                      trailing: state.isDeletingNotes
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: state.noteCount == 0
                                  ? null
                                  : () => _confirmDeleteNotes(context),
                              child: const Text('Delete'),
                            ),
                    ),
                    const Divider(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('Reset onboarding and consent'),
                      subtitle: const Text(
                        'Show the welcome and privacy consent screens again. '
                        'Notes and models are kept.',
                      ),
                      trailing: TextButton(
                        onPressed: () => _resetOnboarding(context),
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  title: 'About',
                  icon: Icons.info_outline,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.apps),
                      title: Text('App version'),
                      trailing: Text('1.0.0'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.code),
                      title: const Text('Open source licenses'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppConfig.appName,
                        applicationVersion: '1.0.0',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uses flutter_edge_ai for on-device language and speech '
                      'inference. This app is not a medical device and does not '
                      'provide medical advice.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppConfig.aiDraftDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _ModelRow extends StatelessWidget {
  const _ModelRow({
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.error_outline,
            color: ready ? theme.colorScheme.primary : theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(ready ? 'Ready' : 'Missing'),
        ],
      ),
    );
  }
}
