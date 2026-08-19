import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import '../cubit/consultation_list_cubit.dart';
import '../cubit/consultation_list_state.dart';

/// Home screen: searchable, filterable list of consultations backed by the
/// on-device note store. Supports pull-to-refresh (which flushes the sync
/// queue) and incremental loading.
class ConsultationListPage extends StatelessWidget {
  const ConsultationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConsultationListCubit(
        localRepository: GetIt.I<NoteLocalRepository>(),
        syncQueueService: GetIt.I<SyncQueueService>(),
      )..load(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consultations'),
          actions: [
            IconButton(
              tooltip: 'AI Model Manager',
              onPressed: () => context.push('/model_manager'),
              icon: const Icon(Icons.smart_toy_outlined),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: BlocBuilder<ConsultationListCubit, ConsultationListState>(
          builder: (context, state) {
            if (state is ConsultationListLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ConsultationListError) {
              return _ErrorView(message: state.message);
            }
            if (state is ConsultationListLoaded) {
              return _ConsultationListBody(state: state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<ConsultationListCubit>().load(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ConsultationListBody extends StatelessWidget {
  final ConsultationListLoaded state;

  const _ConsultationListBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConsultationListCubit>();
    final filtered = state.filtered;

    return Column(
      children: [
        _SearchBar(
          initialQuery: state.searchQuery,
          onChanged: cubit.search,
        ),
        _StatusFilterBar(
          selected: state.statusFilter,
          onSelected: cubit.filterByStatus,
        ),
        _DateFilterBar(
          selected: state.dateFilter,
          onSelected: cubit.filterByDate,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: filtered.isEmpty
                ? _EmptyList(searchQuery: state.searchQuery)
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.extentAfter < 300) {
                        cubit.loadMore();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return const _ListFooter();
                        }
                        final item = filtered[index];
                        return _ConsultationTile(item: item);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String searchQuery;

  const _EmptyList({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchQuery.trim().isNotEmpty;
    // AlwaysScrollableScrollPhysics so pull-to-refresh works even when empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          hasQuery ? Icons.search_off : Icons.notes,
          size: 72,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          hasQuery
              ? 'No consultations match "$searchQuery".'
              : 'No consultations yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pull down to refresh, or open a consultation from the doctor '
          'worklist to start taking notes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConsultationListCubit>();
    final listState = cubit.state;
    if (listState is! ConsultationListLoaded) return const SizedBox.shrink();

    final filtered = listState.filtered;
    final shown = filtered.length < listState.visibleCount
        ? filtered.length
        : listState.visibleCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          cubit.hasMore
              ? 'Loading more…'
              : '$shown of ${listState.all.length} consultations',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.initialQuery, required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by patient or consultation…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          isDense: true,
        ),
        onChanged: (value) => setState(() => widget.onChanged(value)),
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final NoteStatus? selected;
  final ValueChanged<NoteStatus?> onSelected;

  const _StatusFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _filterChip(context, null, 'All'),
            const SizedBox(width: 8),
            _filterChip(context, NoteStatus.draft, 'Draft'),
            const SizedBox(width: 8),
            _filterChip(context, NoteStatus.aiSuggested, 'AI Suggested'),
            const SizedBox(width: 8),
            _filterChip(context, NoteStatus.finalized, 'Finalized'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(BuildContext context, NoteStatus? status, String label) {
    final isSelected = selected == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(isSelected ? null : status),
      showCheckmark: false,
    );
  }
}

class _DateFilterBar extends StatelessWidget {
  final DateFilter selected;
  final ValueChanged<DateFilter> onSelected;

  const _DateFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final filter in DateFilter.values) ...[
              if (filter != DateFilter.all) const SizedBox(width: 8),
              FilterChip(
                label: Text(filter.label),
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
                showCheckmark: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsultationTile extends StatelessWidget {
  final ConsultationListItem item;

  const _ConsultationTile({required this.item});

  String get _relativeTime {
    final diff = DateTime.now().difference(item.updatedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final dt = item.updatedAt.toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (statusLabel, statusColor, statusIcon) = switch (item.status) {
      NoteStatus.draft => ('Draft', scheme.tertiary, Icons.edit_outlined),
      NoteStatus.aiSuggested => (
          'AI Suggested',
          scheme.primary,
          Icons.auto_awesome,
        ),
      NoteStatus.finalized => (
          'Finalized',
          Colors.green.shade800,
          Icons.verified_outlined,
        ),
    };

    return ListTile(
      onTap: () => context.push(
        '/consultation/${item.consultationId}/'
        'patient/${item.patientId}/doctor/${item.doctorId}',
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Consultation ${item.consultationId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(
            label: statusLabel,
            color: statusColor,
            icon: statusIcon,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Patient ${item.patientId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _relativeTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Semantics merged so screen readers announce the status label.
    return Semantics(
      label: 'Status: $label',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}