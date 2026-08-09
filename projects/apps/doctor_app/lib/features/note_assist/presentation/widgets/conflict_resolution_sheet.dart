import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';

/// Manual merge UI for a conflicted sync entry.
///
/// Shows the on-disk version and the queued version side by side and lets
/// the user pick which one to keep. Resolution clears the conflict flag and
/// immediately retries the sync.
class ConflictResolutionSheet extends StatefulWidget {
  final SyncQueueEntry entry;

  const ConflictResolutionSheet({super.key, required this.entry});

  @override
  State<ConflictResolutionSheet> createState() =>
      _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState extends State<ConflictResolutionSheet> {
  DoctorNote? _localNote;
  bool _loading = true;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final note = await GetIt.I<NoteLocalRepository>()
          .getNoteByConsultationId(widget.entry.consultationId);
      if (!mounted) return;
      setState(() {
        _localNote = note;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _keepLocal() async {
    if (_localNote == null) return;
    setState(() => _resolving = true);
    await GetIt.I<SyncQueueService>()
        .resolveConflict(widget.entry.id, _localNote!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _keepQueued() async {
    final queued = widget.entry.note;
    setState(() => _resolving = true);
    // Persist the chosen version locally, then resolve the conflict.
    await GetIt.I<NoteLocalRepository>().saveNote(queued);
    await GetIt.I<SyncQueueService>()
        .resolveConflict(widget.entry.id, queued);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resolve sync conflict',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Two edits were saved at the same time. Choose which '
                  'version to keep — the other will be discarded.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _VersionColumn(
                          title: 'Local (on device)',
                          color: Colors.blue,
                          note: _localNote,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VersionColumn(
                          title: 'Queued (pending sync)',
                          color: Colors.teal,
                          note: widget.entry.note,
                        ),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resolving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _resolving || _localNote == null
                        ? null
                        : _keepLocal,
                    icon: const Icon(Icons.phone_android),
                    label: const Text('Keep local'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _resolving ? null : _keepQueued,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Keep queued'),
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

class _VersionColumn extends StatelessWidget {
  final String title;
  final Color color;
  final DoctorNote? note;

  const _VersionColumn({
    required this.title,
    required this.color,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final text = note?.rawText ?? '';
    final updated = note?.updatedAt;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                if (updated != null)
                  Text(
                    _formatTime(updated),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                text.isEmpty ? '(empty note)' : text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Edited ${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} at $hh:$mm';
  }
}