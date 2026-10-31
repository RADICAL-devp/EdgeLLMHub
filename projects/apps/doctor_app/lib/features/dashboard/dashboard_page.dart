import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/data/note_repository.dart';
import '../../core/models/model_install_progress.dart';
import '../../core/services/model_manager_service.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/app_shell.dart';
import '../../core/ui/responsive.dart';
import '../../core/utils/formatters.dart';
import '../notes/widgets/error_banner.dart';
import '../notes/widgets/note_card.dart';
import 'dashboard_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(
        repository: GetIt.I<NoteRepository>(),
        models: GetIt.I<ModelManagerService>(),
      )..load(),
      child: const _DashboardScaffold(),
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return AppShell(
          title: 'Home',
          currentIndex: 0,
          actions: [
            IconButton(
              tooltip: 'Search notes',
              onPressed: () => context.go(AppRoutes.search),
              icon: const Icon(Icons.search),
            ),
          ],
          child: DashboardView(
            state: state,
            onRefresh: () => context.read<DashboardCubit>().load(),
            onNewNote: () => context.go(AppRoutes.newNote),
            onSearch: () => context.go(AppRoutes.search),
            onSeeAllNotes: () => context.go(AppRoutes.notes),
            onSetup: () => context.go(AppRoutes.setup),
            onOpenNote: (id) => context.go(AppRoutes.note(id)),
          ),
        );
      },
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onNewNote,
    required this.onSearch,
    required this.onSeeAllNotes,
    required this.onSetup,
    required this.onOpenNote,
    this.now,
  });

  final DashboardState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onNewNote;
  final VoidCallback onSearch;
  final VoidCallback onSeeAllNotes;
  final VoidCallback onSetup;
  final ValueChanged<String> onOpenNote;

  /// Injectable clock for deterministic widget and golden tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = now ?? DateTime.now();
    if (state.isLoading && state.totalNotes == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CenteredContent(
            maxWidth: 920,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _greeting(today),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDay(today),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Private, on-device documentation',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: state.error!, onRetry: onRefresh),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onNewNote,
                  icon: const Icon(Icons.add),
                  label: const Text('New clinical note'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Search notes'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSeeAllNotes,
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Saved notes'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ResponsiveCardWrap(
                  minItemWidth: 150,
                  children: [
                    _StatCard(
                      label: 'All notes',
                      value: state.totalNotes,
                      icon: Icons.folder_outlined,
                    ),
                    _StatCard(
                      label: 'Drafts',
                      value: state.drafts,
                      icon: Icons.edit_note,
                    ),
                    _StatCard(
                      label: 'Finalized',
                      value: state.finalized,
                      icon: Icons.verified_outlined,
                    ),
                    _StatCard(
                      label: 'Updated today',
                      value: state.updatedToday,
                      icon: Icons.today_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _AiStatusCard(status: state.modelStatus, onSetup: onSetup),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onSeeAllNotes,
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (state.recentNotes.isEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.note_add_outlined,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No notes yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Record a consultation or type a transcript to '
                            'create your first local note.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: onNewNote,
                            child: const Text('Create a note'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final note in state.recentNotes) ...[
                        NoteCard(note: note, onTap: () => onOpenNote(note.id)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  AppConfig.privacySummary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiStatusCard extends StatelessWidget {
  const _AiStatusCard({required this.status, required this.onSetup});

  final ModelStatus? status;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = status?.allReady ?? false;
    final summary = status?.summary ?? 'Models need setup';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready ? Icons.memory : Icons.warning_amber_outlined,
              color: ready
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'On-device AI ready' : 'Set up on-device AI',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? 'Language and speech models are installed on this '
                              'device.'
                        : '$summary. Download once over Wi-Fi; no patient data '
                              'is sent.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!ready)
              TextButton(onPressed: onSetup, child: const Text('Set up')),
          ],
        ),
      ),
    );
  }
}
