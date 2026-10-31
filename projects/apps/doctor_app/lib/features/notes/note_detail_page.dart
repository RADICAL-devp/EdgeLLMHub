import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/config/app_config.dart';
import '../../core/data/note_repository.dart';
import '../../core/models/clinical_note.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/auto_save_lifecycle.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/status_badge.dart';
import '../../core/utils/formatters.dart';
import 'cubits/note_editor_cubit.dart';
import 'cubits/note_editor_state.dart';
import 'widgets/error_banner.dart';
import 'widgets/save_indicator.dart';
import 'widgets/section_field.dart';

class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NoteEditorCubit(repository: GetIt.I<NoteRepository>())..load(noteId),
      child: _NoteDetailView(noteId: noteId),
    );
  }
}

class _NoteDetailView extends StatefulWidget {
  const _NoteDetailView({required this.noteId});

  final String noteId;

  @override
  State<_NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<_NoteDetailView> with AutoSaveOnPause {
  final _title = TextEditingController();
  final _patient = TextEditingController();
  final _chief = TextEditingController();
  final _hpi = TextEditingController();
  final _exam = TextEditingController();
  final _assessment = TextEditingController();
  final _plan = TextEditingController();
  final _followUp = TextEditingController();

  bool _initialized = false;
  bool _editing = false;

  @override
  Future<void> onAutoSaveRequested() async {
    if (!mounted) return;
    await context.read<NoteEditorCubit>().saveNow();
  }

  @override
  void dispose() {
    _title.dispose();
    _patient.dispose();
    _chief.dispose();
    _hpi.dispose();
    _exam.dispose();
    _assessment.dispose();
    _plan.dispose();
    _followUp.dispose();
    super.dispose();
  }

  void _setController(TextEditingController controller, String? value) {
    final text = value ?? '';
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _syncFromNote(ClinicalNote note) {
    if (_initialized) return;
    _setController(_title, note.title);
    _setController(_patient, note.patientName);
    _setController(_chief, note.sections.chiefComplaint);
    _setController(_hpi, note.sections.historyOfPresentIllness);
    _setController(_exam, note.sections.examination);
    _setController(_assessment, note.sections.assessment);
    _setController(_plan, note.sections.treatmentPlan);
    _setController(_followUp, note.sections.followUp);
    _initialized = true;
  }

  StructuredNoteSections _sections() {
    String? value(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    return StructuredNoteSections(
      chiefComplaint: value(_chief),
      historyOfPresentIllness: value(_hpi),
      examination: value(_exam),
      assessment: value(_assessment),
      treatmentPlan: value(_plan),
      followUp: value(_followUp),
    );
  }

  void _onEditChanged() {
    final cubit = context.read<NoteEditorCubit>();
    cubit.updateTitle(_title.text);
    cubit.updatePatientName(_patient.text);
    cubit.updateSections(_sections());
  }

  Future<void> _startEditing(ClinicalNote note) async {
    if (note.status == NoteStatus.finalized) {
      final reopen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reopen this finalized note?'),
          content: const Text(
            'It will become a draft so it can be edited. You can finalize it '
            'again when you are done.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reopen and edit'),
            ),
          ],
        ),
      );
      if (reopen != true || !mounted) return;
      await context.read<NoteEditorCubit>().reopenNote();
      if (!mounted) return;
    }
    setState(() => _editing = true);
  }

  Future<void> _finishEditing() async {
    final cubit = context.read<NoteEditorCubit>();
    cubit.updateTitle(_title.text);
    cubit.updatePatientName(_patient.text);
    cubit.updateSections(_sections());
    await cubit.saveNow();
    if (!mounted) return;
    setState(() => _editing = false);
  }

  Future<void> _goTo(String route) async {
    final cubit = context.read<NoteEditorCubit>();
    if (_editing) {
      cubit.updateTitle(_title.text);
      cubit.updatePatientName(_patient.text);
      cubit.updateSections(_sections());
      await cubit.saveNow();
    }
    if (!mounted) return;
    context.go(route);
  }

  Future<void> _finalize() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize this note?'),
        content: const Text(
          'The note will be marked finalized. You can reopen it later if you '
          'need to make changes. Review every section first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<NoteEditorCubit>().finalizeNote();
  }

  Future<void> _reopen() async {
    await context.read<NoteEditorCubit>().reopenNote();
  }

  Future<void> _delete(ClinicalNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(
          '“${note.displayTitle}” will be permanently removed from this device. '
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
    if (confirmed != true || !mounted) return;
    final deleted = await context.read<NoteEditorCubit>().deleteNote();
    if (!mounted) return;
    if (deleted) {
      context.go(AppRoutes.notes);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The note could not be deleted. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<NoteEditorCubit, NoteEditorState>(
      builder: (context, state) {
        if (state is NoteEditorLoading || state is NoteEditorInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is NoteEditorFailure) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.notes),
                      child: const Text('Back to notes'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final loaded = state as NoteEditorLoaded;
        final note = loaded.note;
        if (!_initialized) _syncFromNote(note);
        final cubit = context.read<NoteEditorCubit>();

        return PopScope(
          // This route is opened with go(), so it has no route to pop back to.
          // Send the system back gesture to the notes list explicitly.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            cubit.saveNow();
            context.go(AppRoutes.notes);
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Note'),
              leading: IconButton(
                tooltip: 'Back to notes',
                onPressed: () {
                  cubit.saveNow();
                  context.go(AppRoutes.notes);
                },
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                NoteSaveIndicator(state: loaded),
                IconButton(
                  tooltip: _editing ? 'Done editing' : 'Edit note',
                  onPressed: _editing
                      ? _finishEditing
                      : () => _startEditing(note),
                  icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'transcript':
                        _goTo(AppRoutes.transcript(widget.noteId));
                        break;
                      case 'record':
                        _goTo(AppRoutes.record(widget.noteId));
                        break;
                      case 'delete':
                        _delete(note);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'transcript',
                      child: Text('Open transcript'),
                    ),
                    PopupMenuItem(value: 'record', child: Text('Record again')),
                    PopupMenuItem(value: 'delete', child: Text('Delete note')),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: CenteredContent(
                  maxWidth: 840,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          NoteStatusBadge(status: note.status),
                          const Spacer(),
                          Text(
                            formatNoteTimestamp(note.updatedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_editing) ...[
                        TextField(
                          controller: _title,
                          onChanged: (_) => _onEditChanged(),
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Note title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _patient,
                          onChanged: (_) => _onEditChanged(),
                          textCapitalization: TextCapitalization.words,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Patient name or initials',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        Text(
                          note.displayTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.displayPatient,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (loaded.error != null) ...[
                        ErrorBanner(
                          message: loaded.error!,
                          onRetry: cubit.saveNow,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (note.hasStructuredContent) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.fact_check_outlined,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppConfig.aiDraftDisclaimer,
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_editing) ...[
                        for (final field in _sectionFields())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: field,
                          ),
                      ] else if (note.hasStructuredContent)
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionDisplay(
                                  label: 'Chief complaint',
                                  value: note.sections.chiefComplaint,
                                ),
                                const Divider(height: 24),
                                SectionDisplay(
                                  label: 'History of present illness',
                                  value: note.sections.historyOfPresentIllness,
                                ),
                                const Divider(height: 24),
                                SectionDisplay(
                                  label: 'Examination',
                                  value: note.sections.examination,
                                ),
                                const Divider(height: 24),
                                SectionDisplay(
                                  label: 'Assessment',
                                  value: note.sections.assessment,
                                ),
                                const Divider(height: 24),
                                SectionDisplay(
                                  label: 'Treatment plan',
                                  value: note.sections.treatmentPlan,
                                ),
                                const Divider(height: 24),
                                SectionDisplay(
                                  label: 'Follow-up',
                                  value: note.sections.followUp,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_tree_outlined,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No structured sections yet',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Draft the six clinical sections from the '
                                  'transcript, or fill them in manually.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () => _goTo(
                                        AppRoutes.structured(widget.noteId),
                                      ),
                                      icon: const Icon(Icons.auto_awesome),
                                      label: const Text('Draft sections'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _startEditing(note),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit manually'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (note.transcript.trim().isNotEmpty)
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: const Icon(Icons.article_outlined),
                            title: const Text('Transcript'),
                            subtitle: Text(
                              '${wordCount(note.transcript)} words · '
                              '${AppConfig.languageName(note.languageCode)}',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: SelectableText(note.transcript),
                              ),
                            ],
                          ),
                        )
                      else
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: const Text('No transcript yet'),
                            subtitle: const Text(
                              'Record the consultation or type a transcript.',
                            ),
                            trailing: TextButton(
                              onPressed: () =>
                                  _goTo(AppRoutes.transcript(widget.noteId)),
                              child: const Text('Add'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _goTo(AppRoutes.transcript(widget.noteId)),
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('Transcript'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _goTo(AppRoutes.structured(widget.noteId)),
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('Structure with AI'),
                          ),
                          if (_editing)
                            FilledButton.icon(
                              onPressed: _finishEditing,
                              icon: const Icon(Icons.check),
                              label: const Text('Done'),
                            )
                          else if (note.status == NoteStatus.draft)
                            FilledButton.icon(
                              onPressed: _finalize,
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('Finalize note'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _reopen,
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Reopen note'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Created ${formatNoteTimestamp(note.createdAt)} · '
                        'Updated ${formatNoteTimestamp(note.updatedAt)}'
                        '${note.thinkingModeUsed ? ' · Thinking mode used' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
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
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sectionFields() {
    return [
      SectionField(
        label: 'Chief complaint',
        hint: 'e.g., 3 days of sore throat and fever',
        controller: _chief,
        onChanged: (_) => _onEditChanged(),
      ),
      SectionField(
        label: 'History of present illness',
        hint: 'Onset, course, relevant positives and negatives',
        controller: _hpi,
        onChanged: (_) => _onEditChanged(),
        minLines: 4,
        maxLines: 12,
      ),
      SectionField(
        label: 'Examination',
        hint: 'Only findings that were actually stated',
        controller: _exam,
        onChanged: (_) => _onEditChanged(),
      ),
      SectionField(
        label: 'Assessment',
        hint: 'The clinician’s stated impression or differential',
        controller: _assessment,
        onChanged: (_) => _onEditChanged(),
        minLines: 4,
        maxLines: 12,
      ),
      SectionField(
        label: 'Treatment plan',
        hint: 'Medications, advice, tests, and referrals that were stated',
        controller: _plan,
        onChanged: (_) => _onEditChanged(),
        minLines: 4,
        maxLines: 12,
      ),
      SectionField(
        label: 'Follow-up',
        hint: 'Stated timing or follow-up instructions',
        controller: _followUp,
        onChanged: (_) => _onEditChanged(),
      ),
    ];
  }
}
