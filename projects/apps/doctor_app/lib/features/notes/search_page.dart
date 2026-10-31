import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/note_repository.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/app_shell.dart';
import '../../core/ui/responsive.dart';
import '../../core/utils/formatters.dart';
import 'cubits/notes_cubit.dart';
import 'cubits/notes_state.dart';
import 'widgets/error_banner.dart';
import 'widgets/note_card.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SearchCubit(repository: GetIt.I<NoteRepository>())
            ..search(immediate: true),
      child: const _SearchScaffold(),
    );
  }
}

class _SearchScaffold extends StatelessWidget {
  const _SearchScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        final cubit = context.read<SearchCubit>();
        return AppShell(
          title: 'Search',
          currentIndex: 2,
          child: SearchView(
            state: state,
            onQueryChanged: cubit.setQuery,
            onDatesChanged: cubit.setDates,
            onClearDates: cubit.clearDates,
            onClearAll: cubit.clearAll,
            onOpenNote: (id) => context.go(AppRoutes.note(id)),
            onRefresh: () => cubit.search(immediate: true),
          ),
        );
      },
    );
  }
}

class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
    required this.state,
    required this.onQueryChanged,
    required this.onDatesChanged,
    required this.onClearDates,
    required this.onClearAll,
    required this.onOpenNote,
    required this.onRefresh,
  });

  final SearchState state;
  final ValueChanged<String> onQueryChanged;
  final void Function(DateTime? from, DateTime? to) onDatesChanged;
  final VoidCallback onClearDates;
  final VoidCallback onClearAll;
  final ValueChanged<String> onOpenNote;
  final VoidCallback onRefresh;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state.query,
  );

  @override
  void didUpdateWidget(covariant SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.state.query,
        selection: TextSelection.collapsed(offset: widget.state.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: widget.state.from != null && widget.state.to != null
          ? DateTimeRange(start: widget.state.from!, end: widget.state.to!)
          : null,
      helpText: 'Filter notes by date',
      saveText: 'Use dates',
    );
    if (picked != null) {
      widget.onDatesChanged(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final results = state.results;
    final dateLabel = state.hasDateFilter
        ? '${formatShortDate(state.from ?? state.to!)} – '
              '${formatShortDate(state.to ?? state.from!)}'
        : 'Any date';

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CenteredContent(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  onChanged: widget.onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search title, patient, or transcript',
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _controller.clear();
                              widget.onClearAll();
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.date_range, size: 18),
                      label: Text(dateLabel),
                      onPressed: _pickDates,
                    ),
                    if (state.hasDateFilter)
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 18),
                        label: const Text('Clear dates'),
                        onPressed: widget.onClearDates,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Searches stay on this device, including transcript text.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: state.error!, onRetry: widget.onRefresh),
                ],
                if (state.isSearching) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 14),
                if (state.isSearching && results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.hasSearched && results.isEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No matching notes',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try a different word, a shorter phrase, or a wider '
                            'date range.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: widget.onClearAll,
                            child: const Text('Clear search'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (results.isNotEmpty) ...[
                  Text(
                    '${results.length} ${results.length == 1 ? 'note' : 'notes'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final note in results) ...[
                    NoteCard(
                      note: note,
                      onTap: () => widget.onOpenNote(note.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
