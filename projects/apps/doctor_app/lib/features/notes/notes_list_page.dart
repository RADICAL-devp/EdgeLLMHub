import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/note_repository.dart';
import '../../core/models/clinical_note.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/app_shell.dart';
import '../../core/ui/responsive.dart';
import 'cubits/notes_cubit.dart';
import 'cubits/notes_state.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_banner.dart';
import 'widgets/note_card.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NotesCubit(repository: GetIt.I<NoteRepository>())..load(),
      child: const _NotesScaffold(),
    );
  }
}

class _NotesScaffold extends StatelessWidget {
  const _NotesScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        final cubit = context.read<NotesCubit>();
        return AppShell(
          title: 'Notes',
          currentIndex: 1,
          actions: [
            IconButton(
              tooltip: 'Search notes',
              onPressed: () => context.go(AppRoutes.search),
              icon: const Icon(Icons.search),
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go(AppRoutes.newNote),
            icon: const Icon(Icons.add),
            label: const Text('New note'),
          ),
          child: NotesView(
            state: state,
            onRefresh: cubit.load,
            onFilterChanged: cubit.setFilter,
            onOpenNote: (id) => context.go(AppRoutes.note(id)),
            onDeleteNote: cubit.deleteNote,
            onNewNote: () => context.go(AppRoutes.newNote),
          ),
        );
      },
    );
  }
}

class NotesView extends StatelessWidget {
  const NotesView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onFilterChanged,
    required this.onOpenNote,
    required this.onDeleteNote,
    required this.onNewNote,
  });

  final NotesState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<NotesFilter> onFilterChanged;
  final ValueChanged<String> onOpenNote;
  final ValueChanged<String> onDeleteNote;
  final VoidCallback onNewNote;

  Future<bool> _confirmDelete(BuildContext context, ClinicalNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(
          '“${note.displayTitle}” will be removed from this device. '
          'This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteWithConfirm(
    BuildContext context,
    ClinicalNote note,
  ) async {
    if (await _confirmDelete(context, note)) {
      onDeleteNote(note.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = state.visibleNotes;

    if (state.isLoading && state.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          CenteredContent(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Encrypted on this device',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('All  ${state.notes.length}'),
                      selected: state.filter == NotesFilter.all,
                      onSelected: (_) => onFilterChanged(NotesFilter.all),
                    ),
                    ChoiceChip(
                      label: Text('Drafts  ${state.draftCount}'),
                      selected: state.filter == NotesFilter.drafts,
                      onSelected: (_) => onFilterChanged(NotesFilter.drafts),
                    ),
                    ChoiceChip(
                      label: Text('Finalized  ${state.finalizedCount}'),
                      selected: state.filter == NotesFilter.finalized,
                      onSelected: (_) => onFilterChanged(NotesFilter.finalized),
                    ),
                  ],
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: state.error!, onRetry: onRefresh),
                ],
                const SizedBox(height: 16),
                if (notes.isEmpty)
                  _EmptyNotes(
                    filtered: state.filter != NotesFilter.all,
                    onNewNote: onNewNote,
                    onShowAll: () => onFilterChanged(NotesFilter.all),
                  )
                else
                  for (final note in notes) ...[
                    Dismissible(
                      key: ValueKey('note-${note.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context, note),
                      onDismissed: (_) => onDeleteNote(note.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      child: NoteCard(
                        note: note,
                        onTap: () => onOpenNote(note.id),
                        onDelete: () => _deleteWithConfirm(context, note),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({
    required this.filtered,
    required this.onNewNote,
    required this.onShowAll,
  });

  final bool filtered;
  final VoidCallback onNewNote;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (filtered) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No notes in this view',
        message: 'Try another filter or create a new note.',
        action: OutlinedButton(
          onPressed: onShowAll,
          child: const Text('Show all notes'),
        ),
      );
    }
    return EmptyState(
      icon: Icons.note_add_outlined,
      title: 'No saved notes yet',
      message:
          'Record a consultation or type a transcript. Everything stays '
          'on this device.',
      action: FilledButton.icon(
        onPressed: onNewNote,
        icon: const Icon(Icons.add),
        label: const Text('Create your first note'),
      ),
    );
  }
}
