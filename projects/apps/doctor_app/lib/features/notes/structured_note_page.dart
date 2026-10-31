import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/ai/ai_service.dart';
import '../../core/ai/heuristic_note_structurer.dart';
import '../../core/config/app_config.dart';
import '../../core/config/model_config.dart';
import '../../core/data/note_repository.dart';
import '../../core/models/clinical_note.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/auto_save_lifecycle.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/status_badge.dart';
import '../../core/utils/formatters.dart';
import 'cubits/note_editor_cubit.dart';
import 'cubits/note_editor_state.dart';
import 'cubits/structure_note_cubit.dart';
import 'widgets/error_banner.dart';
import 'widgets/save_indicator.dart';
import 'widgets/section_field.dart';

class StructuredNotePage extends StatelessWidget {
  const StructuredNotePage({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              NoteEditorCubit(repository: GetIt.I<NoteRepository>())
                ..load(noteId),
        ),
        BlocProvider(
          create: (context) => StructureNoteCubit(ai: GetIt.I<AIService>()),
        ),
      ],
      child: _StructuredView(noteId: noteId),
    );
  }
}

class _StructuredView extends StatefulWidget {
  const _StructuredView({required this.noteId});

  final String noteId;

  @override
  State<_StructuredView> createState() => _StructuredViewState();
}

class _StructuredViewState extends State<_StructuredView> with AutoSaveOnPause {
  final _chief = TextEditingController();
  final _hpi = TextEditingController();
  final _exam = TextEditingController();
  final _assessment = TextEditingController();
  final _plan = TextEditingController();
  final _followUp = TextEditingController();

  bool _initialized = false;
  bool _autoTried = false;
  bool _generating = false;
  bool _thinking = false;
  String? _aiError;

  @override
  Future<void> onAutoSaveRequested() async {
    if (!mounted) return;
    await context.read<NoteEditorCubit>().saveNow();
  }

  @override
  void dispose() {
    _chief.dispose();
    _hpi.dispose();
    _exam.dispose();
    _assessment.dispose();
    _plan.dispose();
    _followUp.dispose();
    super.dispose();
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

  void _setController(TextEditingController controller, String? value) {
    final text = value ?? '';
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setControllersFromSections(StructuredNoteSections sections) {
    _setController(_chief, sections.chiefComplaint);
    _setController(_hpi, sections.historyOfPresentIllness);
    _setController(_exam, sections.examination);
    _setController(_assessment, sections.assessment);
    _setController(_plan, sections.treatmentPlan);
    _setController(_followUp, sections.followUp);
  }

  void _syncFromNote(ClinicalNote note) {
    if (_initialized) return;
    _setControllersFromSections(note.sections);
    _thinking = note.thinkingModeUsed;
    _initialized = true;

    if (note.sections.isEmpty &&
        note.transcript.trim().isNotEmpty &&
        !_autoTried) {
      _autoTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate(auto: true);
      });
    }
  }

  void _onSectionChanged() {
    context.read<NoteEditorCubit>().updateSections(_sections());
  }

  Future<void> _generate({required bool auto}) async {
    if (_generating) return;
    final noteCubit = context.read<NoteEditorCubit>();
    final aiCubit = context.read<StructureNoteCubit>();
    final noteState = noteCubit.state;
    if (noteState is! NoteEditorLoaded) return;
    final note = noteState.note;

    if (note.transcript.trim().isEmpty) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a transcript before asking the model to draft.'),
          ),
        );
      }
      return;
    }

    if (!aiCubit.isReady) {
      if (!auto) await _showSetupDialog();
      return;
    }

    if (!auto) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generate a new draft?'),
          content: const Text(
            'The current section text will be replaced by a new AI draft. '
            'Your transcript is not changed. You can edit the new draft or '
            'use the transcript scaffold instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Generate draft'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _generating = true;
      _aiError = null;
    });

    final sections = await aiCubit.generate(
      transcript: note.transcript,
      languageCode: note.languageCode,
      enableThinking: _thinking,
      patientName: note.patientName,
    );

    if (!mounted) return;
    if (sections == null) {
      setState(() {
        _generating = false;
        _aiError =
            aiCubit.state.error ??
            'The on-device model could not draft this note. Try again.';
      });
      return;
    }

    _setControllersFromSections(sections);
    noteCubit.updateSections(sections);
    noteCubit.setThinkingModeUsed(_thinking);
    noteCubit.updateModelName(ModelCatalog.llm.displayName);
    await noteCubit.saveNow();
    if (!mounted) return;
    setState(() => _generating = false);
  }

  Future<void> _showSetupDialog() async {
    final action = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('On-device model needed'),
        content: const Text(
          'Download the language model to draft sections from this transcript. '
          'You can also fill the sections manually or use the transcript '
          'scaffold without AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set up AI'),
          ),
        ],
      ),
    );
    if (action == true && mounted) context.go(AppRoutes.setup);
  }

  Future<void> _toggleThinking(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn on thinking mode?'),
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
      if (confirmed != true || !mounted) return;
    }
    setState(() => _thinking = value);
    final cubit = context.read<NoteEditorCubit>();
    cubit.setThinkingModeUsed(value);
    cubit.saveNow();
  }

  Future<void> _useTranscriptScaffold() async {
    final cubit = context.read<NoteEditorCubit>();
    final noteState = cubit.state;
    if (noteState is! NoteEditorLoaded) return;
    final scaffold = const HeuristicNoteStructurer().scaffold(
      noteState.note.transcript,
    );
    if (scaffold.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no transcript to copy.')),
      );
      return;
    }
    _setControllersFromSections(scaffold);
    cubit.updateSections(scaffold);
    await cubit.saveNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filled a scaffold from the transcript. Review it.'),
      ),
    );
  }

  Future<void> _saveDraft() async {
    final cubit = context.read<NoteEditorCubit>();
    cubit.updateSections(_sections());
    await cubit.saveNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved on this device.')),
    );
  }

  Future<void> _finalize() async {
    final cubit = context.read<NoteEditorCubit>();
    cubit.updateSections(_sections());
    await cubit.saveNow();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize this note?'),
        content: const Text(
          'The note will be marked finalized. You can still reopen and edit it '
          'later. Review every section before continuing.',
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

    await cubit.finalizeNote();
    if (!mounted) return;
    context.go(AppRoutes.note(widget.noteId));
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
            appBar: AppBar(title: const Text('Structured note')),
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
        final aiReady = GetIt.I<AIService>().isReady;

        return PopScope(
          // The route is opened with go(), so provide an explicit parent.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            cubit.saveNow();
            context.go(AppRoutes.note(widget.noteId));
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Structured note'),
              leading: IconButton(
                tooltip: 'Back to note',
                onPressed: () {
                  cubit.saveNow();
                  context.go(AppRoutes.note(widget.noteId));
                },
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                NoteSaveIndicator(state: loaded),
                const SizedBox(width: 8),
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
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'AI draft — review every section',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          NoteStatusBadge(status: note.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note.displayTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        note.displayPatient,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_generating) ...[
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 10),
                                Text(
                                  _thinking
                                      ? 'Drafting with thinking mode. This can '
                                            'take several minutes on this device.'
                                      : 'Drafting on this device. This can take '
                                            'a little while for a long '
                                            'consultation.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (_thinking) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    AppConfig.thinkingModeWarning,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_aiError != null) ...[
                        const SizedBox(height: 12),
                        ErrorBanner(
                          message: _aiError!,
                          onRetry: _generating
                              ? null
                              : () => _generate(auto: false),
                          onDismiss: () => setState(() => _aiError = null),
                        ),
                      ],
                      if (loaded.error != null) ...[
                        const SizedBox(height: 12),
                        ErrorBanner(
                          message: loaded.error!,
                          onRetry: cubit.saveNow,
                        ),
                      ],
                      if (!aiReady) ...[
                        const SizedBox(height: 12),
                        _SetupNotice(
                          onSetup: () => context.go(AppRoutes.setup),
                        ),
                      ],
                      if (note.transcript.trim().isEmpty) ...[
                        const SizedBox(height: 12),
                        _Notice(
                          icon: Icons.mic_none,
                          text:
                              'This note has no transcript yet. Add or record '
                              'a transcript, then come back to draft sections.',
                          action: TextButton(
                            onPressed: () =>
                                context.go(AppRoutes.transcript(widget.noteId)),
                            child: const Text('Add transcript'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              value: _thinking,
                              onChanged: _generating ? null : _toggleThinking,
                              title: const Text('Thinking mode'),
                              subtitle: const Text(
                                'Off by default. Slower, but can help with '
                                'complex or long consultations.',
                              ),
                              secondary: const Icon(Icons.psychology_outlined),
                            ),
                            if (_thinking)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    AppConfig.thinkingModeWarning,
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SectionField(
                        label: 'Chief complaint',
                        hint: 'e.g., 3 days of sore throat and fever',
                        controller: _chief,
                        onChanged: (_) => _onSectionChanged(),
                        enabled: !_generating,
                      ),
                      const SizedBox(height: 12),
                      SectionField(
                        label: 'History of present illness',
                        hint: 'Onset, course, relevant positives and negatives',
                        controller: _hpi,
                        onChanged: (_) => _onSectionChanged(),
                        minLines: 4,
                        maxLines: 12,
                        enabled: !_generating,
                      ),
                      const SizedBox(height: 12),
                      SectionField(
                        label: 'Examination',
                        hint: 'Only findings that were actually stated',
                        controller: _exam,
                        onChanged: (_) => _onSectionChanged(),
                        enabled: !_generating,
                      ),
                      const SizedBox(height: 12),
                      SectionField(
                        label: 'Assessment',
                        hint:
                            'The clinician’s stated impression or differential',
                        controller: _assessment,
                        onChanged: (_) => _onSectionChanged(),
                        minLines: 4,
                        maxLines: 12,
                        enabled: !_generating,
                      ),
                      const SizedBox(height: 12),
                      SectionField(
                        label: 'Treatment plan',
                        hint:
                            'Medications, advice, tests, and referrals that '
                            'were stated',
                        controller: _plan,
                        onChanged: (_) => _onSectionChanged(),
                        minLines: 4,
                        maxLines: 12,
                        enabled: !_generating,
                      ),
                      const SizedBox(height: 12),
                      SectionField(
                        label: 'Follow-up',
                        hint: 'Stated timing or follow-up instructions',
                        controller: _followUp,
                        onChanged: (_) => _onSectionChanged(),
                        enabled: !_generating,
                      ),
                      if (note.transcript.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: const Icon(Icons.article_outlined),
                            title: const Text('Source transcript'),
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
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _generating
                                ? null
                                : _useTranscriptScaffold,
                            icon: const Icon(Icons.content_paste),
                            label: const Text('Fill from transcript'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _generating ||
                                    !aiReady ||
                                    note.transcript.trim().isEmpty
                                ? null
                                : () => _generate(auto: false),
                            icon: _generating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Regenerate'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _generating ? null : _saveDraft,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save draft'),
                          ),
                          FilledButton.icon(
                            onPressed: _generating ? null : _finalize,
                            icon: const Icon(Icons.check),
                            label: const Text('Finalize note'),
                          ),
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The on-device language model is not installed. Download it once '
              'to draft sections automatically. You can still edit manually or '
              'fill a scaffold from the transcript.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onSetup, child: const Text('Set up')),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
