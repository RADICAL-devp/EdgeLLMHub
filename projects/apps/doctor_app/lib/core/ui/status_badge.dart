import 'package:flutter/material.dart';

import '../models/clinical_note.dart';

class NoteStatusBadge extends StatelessWidget {
  const NoteStatusBadge({super.key, required this.status});

  final NoteStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalized = status == NoteStatus.finalized;
    final background = finalized
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = finalized
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        finalized ? 'Finalized' : 'Draft',
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
