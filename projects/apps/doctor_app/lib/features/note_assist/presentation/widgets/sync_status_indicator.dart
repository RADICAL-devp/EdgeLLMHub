import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'conflict_resolution_sheet.dart';

enum SyncStatus {
  synced,
  syncing,
  pending,
  conflict,
  error,
  deadLetter,
}

/// Live sync status pill for a consultation.
///
/// Derives its state from the [SyncQueueService] queue stream plus the
/// editor cubit's in-flight/error flags. Tapping opens a detail sheet with
/// retry and conflict-resolution actions.
class SyncStatusIndicator extends StatelessWidget {
  final String consultationId;
  final bool isSyncing;
  final String? syncError;
  final VoidCallback? onRetry;

  const SyncStatusIndicator({
    super.key,
    required this.consultationId,
    this.isSyncing = false,
    this.syncError,
    this.onRetry,
  });

  SyncStatus _deriveStatus(SyncQueueEntry? entry) {
    if (isSyncing) return SyncStatus.syncing;
    if (entry?.isConflict ?? false) return SyncStatus.conflict;
    if (entry?.isDeadLetter ?? false) return SyncStatus.deadLetter;
    if (entry != null) return SyncStatus.pending;
    if (syncError != null) return SyncStatus.error;
    return SyncStatus.synced;
  }

  @override
  Widget build(BuildContext context) {
    final syncQueue = GetIt.I<SyncQueueService>();

    return StreamBuilder<List<SyncQueueEntry>>(
      stream: syncQueue.watchEntries(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <SyncQueueEntry>[];
        SyncQueueEntry? entry;
        for (final e in entries) {
          if (e.consultationId == consultationId) {
            entry = e;
            break;
          }
        }

        final status = _deriveStatus(entry);
        final (label, color, icon) = switch (status) {
          SyncStatus.synced => (
              'Saved',
              Colors.green,
              Icons.cloud_done,
            ),
          SyncStatus.syncing => (
              'Syncing…',
              Colors.orange,
              Icons.cloud_upload,
            ),
          SyncStatus.pending => (
              'Pending sync',
              Colors.orange,
              Icons.cloud_upload,
            ),
          SyncStatus.conflict => (
              'Conflict',
              Colors.amber.shade800,
              Icons.warning_amber,
            ),
          SyncStatus.error => (
              'Offline',
              Colors.red,
              Icons.cloud_off,
            ),
          SyncStatus.deadLetter => (
              'Sync failed',
              Colors.red,
              Icons.error_outline,
            ),
        };

        return Semantics(
          label: 'Sync status: $label',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showDetails(context, entry, status),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == SyncStatus.syncing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    SyncQueueEntry? entry,
    SyncStatus status,
  ) async {
    final syncQueue = GetIt.I<SyncQueueService>();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final retryText = entry?.lastError != null
            ? '${entry!.lastError}\n'
            : '';
        final retryMeta = entry != null
            ? 'Retries: ${entry.retryCount}/${entry.maxRetries}'
            : 'No queued entry';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sync details — Consultation $consultationId',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  retryText.isNotEmpty
                      ? '$retryText$retryMeta'
                      : retryMeta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 16),
                if (status == SyncStatus.conflict && entry != null)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openMergeSheet(context, entry);
                    },
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Resolve conflict'),
                  ),
                if (status == SyncStatus.pending ||
                    status == SyncStatus.deadLetter)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      syncQueue.syncNow();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Retry now'),
                  ),
                if (onRetry != null && status == SyncStatus.error) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onRetry!();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Retry now'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMergeSheet(
    BuildContext context,
    SyncQueueEntry entry,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ConflictResolutionSheet(entry: entry),
    );
  }
}