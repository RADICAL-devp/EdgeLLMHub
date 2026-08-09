import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../cubit/note_editor_cubit.dart';
import '../cubit/note_editor_state.dart';
import '../cubit/ai_assist_cubit.dart';
import '../cubit/ai_assist_state.dart';
import '../../../../core/services/speech_service.dart';
import '../../domain/models/doctor_note.dart';
import 'package:get_it/get_it.dart';
import 'dart:convert';
import '../widgets/ai_toolbar.dart';
import '../widgets/suggestion_panel.dart';
import '../widgets/sync_status_indicator.dart';

class NoteEditorPage extends StatefulWidget {
  final String consultationId;
  final String patientId;
  final String doctorId;

  const NoteEditorPage({
    super.key,
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late QuillController _quillController;
  final _speechService = GetIt.I<SpeechService>();
  double _fontSize = 16;
  static const _minFontSize = 12.0;
  static const _maxFontSize = 24.0;

  /// Set once the note content has been restored into the editor so
  /// subsequent state re-emissions never clobber the user's typing.
  bool _initialized = false;

  /// While true, programmatic document changes are not re-broadcast to
  /// the cubit (avoids feedback loops during content restore).
  bool _suspended = false;

  /// Last serialized delta — used to skip no-op changes (e.g. cursor moves).
  String _lastDelta = '';

  String get _plainText => _quillController.document.toPlainText();

  int get _wordCount {
    final text = _plainText.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _quillController.addListener(_onEditorChanged);

    context.read<NoteEditorCubit>().loadOrCreateNote(
          consultationId: widget.consultationId,
          patientId: widget.patientId,
          doctorId: widget.doctorId,
        );
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  /// Keep the cubit (and therefore persistence + sync queue) in sync with
  /// the rich-text document. Content changes only — cursor moves are
  /// filtered out by comparing the serialized delta.
  void _onEditorChanged() {
    if (_suspended) return;
    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    if (deltaJson == _lastDelta) return;
    _lastDelta = deltaJson;
    setState(() {});
    context.read<NoteEditorCubit>().updateText(_plainText,
        richTextDelta: deltaJson);
  }

  /// Restore note content into the editor on first load. Rich text is
  /// restored from the persisted Delta when available, otherwise the plain
  /// text is inserted (formatting starts fresh).
  void _restoreContent(DoctorNote note) {
    _suspended = true;
    try {
      if (note.richTextDelta != null && note.richTextDelta!.isNotEmpty) {
        _quillController.document = Document.fromJson(
          (jsonDecode(note.richTextDelta!) as List)
              .cast<Map<String, dynamic>>(),
        );
      } else if (note.rawText.isNotEmpty) {
        _quillController.replaceText(
          0,
          _quillController.document.length,
          note.rawText,
          TextSelection.collapsed(offset: note.rawText.length),
        );
      }
    } catch (_) {
      // Corrupt delta — fall back to plain text.
      _quillController.document = Document();
      _quillController.replaceText(
        0,
        0,
        note.rawText,
        TextSelection.collapsed(offset: note.rawText.length),
      );
    } finally {
      _suspended = false;
      _lastDelta = jsonEncode(_quillController.document.toDelta().toJson());
      setState(() {});
    }
  }

  /// Insert [text] at the end of the document (dictation / AI suggestion).
  void _insertAtEnd(String text, {String separator = ' '}) {
    final doc = _quillController.document;
    final plain = doc.toPlainText();
    if (plain.isNotEmpty &&
        !plain.endsWith(' ') &&
        !plain.endsWith('\n') &&
        separator.isNotEmpty) {
      text = '$separator$text';
    }
    final newOffset = doc.length + text.length;
    _quillController.replaceText(
      doc.length,
      0,
      text,
      TextSelection.collapsed(offset: newOffset),
    );
  }

  void _toggleListening(NoteEditorLoaded state) async {
    final cubit = context.read<NoteEditorCubit>();
    if (state.isListening) {
      await _speechService.stopListening();
      cubit.setListening(false);
    } else {
      cubit.setListening(true);
      await _speechService.startListening((text) {
        if (text.isNotEmpty) _insertAtEnd(text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteEditorCubit, NoteEditorState>(
      listener: (context, state) {
        if (state is NoteEditorLoaded && !_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restoreContent(state.note);
          });
        }
      },
      builder: (context, state) {
        if (state is NoteEditorLoading || state is NoteEditorInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is NoteEditorError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        if (state is NoteEditorLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Consultation Notes'),
              actions: [
                SyncStatusIndicator(
                  consultationId: widget.consultationId,
                  isSyncing: state.isSyncing,
                  syncError: state.error,
                  onRetry: () =>
                      context.read<NoteEditorCubit>().retrySync(),
                ),
              ],
            ),
            body: Column(
              children: [
                SuggestionPanel(
                  onAccept: (suggestion) {
                    final aiState = context.read<AiAssistCubit>().state;
                    if (aiState is AiAssistSuggestionReady) {
                      if (aiState.action == 'extracting fields') {
                        // For extraction, we update the note's extractedFields instead of text
                        final currentNote = state.note;
                        try {
                          final parsedJson = jsonDecode(suggestion);
                          final extracted =
                              ExtractedFields.fromJson(parsedJson);
                          final updatedNote =
                              currentNote.copyWith(extractedFields: extracted);
                          context
                              .read<NoteEditorCubit>()
                              .saveNoteFields(updatedNote);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Failed to parse extracted fields.')),
                          );
                        }
                      } else if (aiState.action == 'generating recap') {
                        final currentNote = state.note;
                        final updatedNote =
                            currentNote.copyWith(patientRecap: suggestion);
                        context
                            .read<NoteEditorCubit>()
                            .saveNoteFields(updatedNote);
                      } else {
                        _insertAtEnd(suggestion, separator: '\n\n');
                      }
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _EditorStatusBar(
                          status: state.note.status,
                          fontSize: _fontSize,
                          onDecreaseFont: () => setState(() {
                            _fontSize = (_fontSize - 2)
                                .clamp(_minFontSize, _maxFontSize);
                          }),
                          onIncreaseFont: () => setState(() {
                            _fontSize = (_fontSize + 2)
                                .clamp(_minFontSize, _maxFontSize);
                          }),
                        ),
                        const SizedBox(height: 8),
                        QuillSimpleToolbar(
                          controller: _quillController,
                          config: const QuillSimpleToolbarConfig(
                            multiRowsDisplay: true,
                            showDividers: false,
                            showFontFamily: false,
                            showFontSize: false,
                            showHeaderStyle: true,
                            showColorButton: true,
                            showBackgroundColorButton: false,
                            showInlineCode: false,
                            showStrikeThrough: true,
                            showUnderLineButton: true,
                            showClearFormat: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: QuillEditor.basic(
                              controller: _quillController,
                              config: QuillEditorConfig(
                                placeholder:
                                    'Start typing or dictating your notes...',
                                expands: true,
                                padding: const EdgeInsets.all(12),
                                customStyles: DefaultStyles(
                                  paragraph: TextStyle(
                                    fontSize: _fontSize,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AiToolbar(currentText: _plainText),
                        if (state.note.extractedFields != null) ...[
                          const SizedBox(height: 16),
                          ExpansionTile(
                            title: const Text('Extracted Fields'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(_formatExtractedFields(
                                    state.note.extractedFields!)),
                              ),
                            ],
                          ),
                        ],
                        if (state.note.patientRecap != null) ...[
                          const SizedBox(height: 16),
                          ExpansionTile(
                            title: const Text('Patient Recap'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(state.note.patientRecap!),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Semantics(
                          label: '$_wordCount words',
                          child: Text(
                            '$_wordCount words · '
                            '${_plainText.characters.length} chars',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: Semantics(
              label: state.isListening
                  ? 'Stop listening'
                  : 'Start voice dictation',
              button: true,
              child: FloatingActionButton(
                onPressed: () => _toggleListening(state),
                backgroundColor:
                    state.isListening ? Colors.red : null,
                tooltip: state.isListening
                    ? 'Stop listening'
                    : 'Start voice dictation',
                child: Icon(
                    state.isListening ? Icons.mic : Icons.mic_none),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  String _formatExtractedFields(ExtractedFields fields) {
    final buffer = StringBuffer();
    if (fields.provisionalDiagnosis != null)
      buffer.writeln('Diagnosis: ${fields.provisionalDiagnosis}');
    if (fields.duration != null) buffer.writeln('Duration: ${fields.duration}');
    if (fields.symptoms.isNotEmpty)
      buffer.writeln('Symptoms: ${fields.symptoms.join(', ')}');
    if (fields.medications.isNotEmpty)
      buffer.writeln('Medications: ${fields.medications.join(', ')}');
    if (fields.allergies.isNotEmpty)
      buffer.writeln('Allergies: ${fields.allergies.join(', ')}');
    if (fields.testsRecommended.isNotEmpty)
      buffer.writeln('Tests: ${fields.testsRecommended.join(', ')}');
    if (fields.followUpActions.isNotEmpty)
      buffer.writeln('Follow Up: ${fields.followUpActions.join(', ')}');
    return buffer.toString().trim();
  }
}

class _EditorStatusBar extends StatelessWidget {
  final NoteStatus status;
  final double fontSize;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;

  const _EditorStatusBar({
    required this.status,
    required this.fontSize,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
  });

  String get _statusLabel => switch (status) {
        NoteStatus.draft => 'Draft',
        NoteStatus.aiSuggested => 'AI Suggested',
        NoteStatus.finalized => 'Finalized',
      };

  IconData get _statusIcon => switch (status) {
        NoteStatus.draft => Icons.edit_outlined,
        NoteStatus.aiSuggested => Icons.auto_awesome,
        NoteStatus.finalized => Icons.verified_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      NoteStatus.draft => scheme.tertiary,
      NoteStatus.aiSuggested => scheme.primary,
      NoteStatus.finalized => Colors.green.shade800,
    };

    return Row(
      children: [
        Semantics(
          label: 'Note status: $_statusLabel',
          container: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Decrease text size',
          icon: const Icon(Icons.text_decrease),
          onPressed: onDecreaseFont,
          visualDensity: VisualDensity.compact,
        ),
        Semantics(
          label: 'Text size ${fontSize.round()} pixels',
          child: Text(
            '${fontSize.round()}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton(
          tooltip: 'Increase text size',
          icon: const Icon(Icons.text_increase),
          onPressed: onIncreaseFont,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
