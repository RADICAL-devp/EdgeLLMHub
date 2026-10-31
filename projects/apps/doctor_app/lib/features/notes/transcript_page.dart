import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/ai_service.dart';
import '../../core/config/app_config.dart';
import '../../core/data/note_repository.dart';
import '../../core/models/clinical_note.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/auto_save_lifecycle.dart';
import '../../core/utils/formatters.dart';
import 'cubits/note_editor_cubit.dart';
import 'cubits/note_editor_state.dart';
import 'cubits/structure_note_cubit.dart';
import 'widgets/error_banner.dart';
import 'widgets/save_indicator.dart';

class TranscriptPage extends StatelessWidget {
  const TranscriptPage({super.key, required this.noteId});

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
      child: _TranscriptView(noteId: noteId),
    );
  }
}

class _TranscriptView extends StatefulWidget {
  const _TranscriptView({required this.noteId});

  final String noteId;

  @override
  State<_TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<_TranscriptView> with AutoSaveOnPause {
  final TextEditingController _controller = TextEditingController();
  bool _initialized = false;
  bool _cleaning = false;
  int _words = 0;
  String? _aiError;

  @override
  Future<void> onAutoSaveRequested() async {
    if (!mounted) return;
    await context.read<NoteEditorCubit>().saveNow();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncFromNote(ClinicalNote note) {
    if (_initialized) return;
    _controller.text = note.transcript;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _words = wordCount(note.transcript);
    _initialized = true;
  }

  Future<void> _cleanUp(ClinicalNote note) async {
    final original = _controller.text.trim();
    if (original.isEmpty || _cleaning) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean up this transcript?'),
        content: const Text(
          'The on-device model will fix punctuation and filler words without '
          'summarizing. It may occasionally change a word. You can undo '
          'immediately after it finishes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clean up'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cleaning = true;
      _aiError = null;
    });
    final aiCubit = context.read<StructureNoteCubit>();
    final cleaned = await aiCubit.cleanTranscript(
      transcript: original,
      languageCode: note.languageCode,
      enableThinking: false,
    );
    if (!mounted) return;

    if (cleaned == null || cleaned.trim().isEmpty) {
      setState(() {
        _cleaning = false;
        _aiError =
            aiCubit.state.error ??
            'The transcript could not be cleaned. The original text was kept.';
      });
      return;
    }

    final noteCubit = context.read<NoteEditorCubit>();
    _controller.text = cleaned;
    _controller.selection = TextSelection.collapsed(offset: cleaned.length);
    setState(() {
      _cleaning = false;
      _words = wordCount(cleaned);
    });
    noteCubit.updateTranscript(cleaned);
    noteCubit.updateCleanedTranscript(cleaned);
    await noteCubit.saveNow();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transcript cleaned.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _controller.text = original;
            _controller.selection = TextSelection.collapsed(
              offset: original.length,
            );
            setState(() => _words = wordCount(original));
            noteCubit.updateTranscript(original);
            noteCubit.updateCleanedTranscript(original);
            noteCubit.saveNow();
          },
        ),
      ),
    );
  }

  Future<void> _openStructured(ClinicalNote note) async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a transcript before structuring.')),
      );
      return;
    }
    final noteCubit = context.read<NoteEditorCubit>();
    noteCubit.updateTranscript(_controller.text);
    await noteCubit.saveNow();
    if (!mounted) return;
    context.go(AppRoutes.structured(widget.noteId));
  }

  void _onChanged(String value) {
    context.read<NoteEditorCubit>().updateTranscript(value);
    setState(() => _words = wordCount(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<NoteEditorCubit, NoteEditorState>(
      listenWhen: (previous, current) =>
          current is NoteEditorLoaded &&
          (!_initialized || previous is! NoteEditorLoaded),
      listener: (context, state) {
        if (state is NoteEditorLoaded) {
          _syncFromNote(state.note);
        }
      },
      builder: (context, state) {
        if (state is NoteEditorLoading || state is NoteEditorInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is NoteEditorFailure) {
          return Scaffold(
            appBar: AppBar(title: const Text('Transcript')),
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
        final aiReady = GetIt.I<AIService>().isReady;
        final noteCubit = context.read<NoteEditorCubit>();

        return PopScope(
          // The route is opened with go(), so provide an explicit parent.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            noteCubit.saveNow();
            context.go(AppRoutes.note(widget.noteId));
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Transcript'),
              leading: IconButton(
                tooltip: 'Back to note',
                onPressed: () {
                  noteCubit.saveNow();
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
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                                'Stored encrypted on this device',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${AppConfig.languageName(note.languageCode)} · '
                              '$_words words',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
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
                        const SizedBox(height: 10),
                        if (_aiError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ErrorBanner(
                              message: _aiError!,
                              onDismiss: () => setState(() => _aiError = null),
                            ),
                          ),
                        if (loaded.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ErrorBanner(
                              message: loaded.error!,
                              onRetry: () =>
                                  context.read<NoteEditorCubit>().saveNow(),
                            ),
                          ),
                        if (_cleaning) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 4),
                          Text(
                            'Cleaning up on this device…',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: _onChanged,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              labelText: 'Transcript',
                              alignLabelWithHint: true,
                              hintText: note.transcript.isEmpty
                                  ? 'Type or paste the consultation transcript '
                                        'here, or record the consultation.'
                                  : 'Edit the transcript. Changes save '
                                        'automatically.',
                              border: const OutlineInputBorder(),
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (note.transcript.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  context.go(AppRoutes.record(widget.noteId)),
                              icon: const Icon(Icons.mic_none),
                              label: const Text('Record instead'),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  _cleaning ||
                                      !aiReady ||
                                      _controller.text.trim().isEmpty
                                  ? null
                                  : () => _cleanUp(note),
                              icon: _cleaning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_fix_high),
                              label: const Text('Clean up'),
                            ),
                            FilledButton.icon(
                              onPressed: _controller.text.trim().isEmpty
                                  ? null
                                  : () => _openStructured(note),
                              icon: const Icon(Icons.account_tree_outlined),
                              label: const Text('Structure note'),
                            ),
                          ],
                        ),
                        if (!aiReady)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Clean up needs the on-device language '
                                    'model. You can still edit and structure '
                                    'manually.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go(AppRoutes.setup),
                                  child: const Text('Set up'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
