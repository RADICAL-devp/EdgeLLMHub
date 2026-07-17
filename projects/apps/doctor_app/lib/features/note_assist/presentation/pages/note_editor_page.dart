import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  late TextEditingController _textController;
  final _speechService = GetIt.I<SpeechService>();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();

    context.read<NoteEditorCubit>().loadOrCreateNote(
          consultationId: widget.consultationId,
          patientId: widget.patientId,
          doctorId: widget.doctorId,
        );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleListening(NoteEditorLoaded state) async {
    final cubit = context.read<NoteEditorCubit>();
    if (state.isListening) {
      await _speechService.stopListening();
      cubit.setListening(false);
    } else {
      cubit.setListening(true);
      await _speechService.startListening((text) {
        if (text.isNotEmpty) {
          final currentText = _textController.text;
          final newText = currentText.isEmpty ? text : '$currentText $text';
          _textController.text = newText;
          cubit.updateText(newText);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteEditorCubit, NoteEditorState>(
      listener: (context, state) {
        if (state is NoteEditorLoaded &&
            _textController.text != state.note.rawText) {
          // Only update if it's not the user currently typing
          if (!FocusScope.of(context).hasFocus) {
            _textController.text = state.note.rawText;
          }
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
          // Set initial text once it's loaded if controller is empty
          if (_textController.text.isEmpty && state.note.rawText.isNotEmpty) {
            _textController.text = state.note.rawText;
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Consultation Notes'),
              actions: [
                if (state is NoteEditorLoaded)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.isSyncing)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (state.error != null)
                            const Icon(Icons.cloud_off,
                                size: 16, color: Colors.red)
                          else
                            const Icon(Icons.cloud_done,
                                size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            state.isSyncing
                                ? 'Syncing...'
                                : (state.error != null ? 'Offline' : 'Saved'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ),
                    ),
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
                        final currentText = _textController.text;
                        final newText = currentText.isEmpty
                            ? suggestion
                            : '$currentText\n\n$suggestion';
                        _textController.text = newText;
                        context.read<NoteEditorCubit>().updateText(newText);
                      }
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              hintText:
                                  'Start typing or dictating your notes...',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (text) => context
                                .read<NoteEditorCubit>()
                                .updateText(text),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AiToolbar(currentText: _textController.text),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _toggleListening(state),
              child: Icon(state.isListening ? Icons.mic : Icons.mic_none),
              backgroundColor: state.isListening ? Colors.red : null,
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
