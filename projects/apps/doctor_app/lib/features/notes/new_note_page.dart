import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/data/note_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/responsive.dart';
import 'cubits/note_editor_cubit.dart';

class NewNotePage extends StatefulWidget {
  const NewNotePage({super.key});

  @override
  State<NewNotePage> createState() => _NewNotePageState();
}

class _NewNotePageState extends State<NewNotePage> {
  late final NoteEditorCubit _noteCubit;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();

  late String _languageCode;
  bool _thinking = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _noteCubit = NoteEditorCubit(repository: GetIt.I<NoteRepository>());
    final settings = GetIt.I<SettingsService>();
    _languageCode = settings.languageCode;
    _thinking = settings.thinkingMode;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _patientController.dispose();
    _noteCubit.close();
    super.dispose();
  }

  Future<void> _createNote({required bool record}) async {
    if (_busy) return;
    if (record && !GetIt.I<TranscriptionService>().isReady) {
      await _showSpeechModelDialog();
      return;
    }

    setState(() => _busy = true);
    final note = await _noteCubit.create(
      title: _titleController.text.trim(),
      patientName: _patientController.text.trim(),
      languageCode: _languageCode,
    );

    if (note == null) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The note could not be created on this device.'),
        ),
      );
      return;
    }

    if (_thinking) {
      _noteCubit.setThinkingModeUsed(true);
      await _noteCubit.saveNow();
    }

    if (!mounted) return;
    context.go(
      record ? AppRoutes.record(note.id) : AppRoutes.transcript(note.id),
    );
  }

  Future<void> _showSpeechModelDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speech model not ready'),
        content: const Text(
          'Download the on-device speech model before recording. You can still '
          'type or paste a transcript now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('type'),
            child: const Text('Type transcript'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('setup'),
            child: const Text('Set up AI'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'setup') {
      context.go(AppRoutes.setup);
    } else if (action == 'type') {
      await _createNote(record: false);
    }
  }

  Future<void> _setThinking(bool value) async {
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
      if (confirmed != true) return;
    }
    setState(() => _thinking = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New clinical note'),
        leading: IconButton(
          tooltip: 'Back to notes',
          onPressed: () => context.go(AppRoutes.notes),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: CenteredContent(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Start a note',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The transcript and note stay on this device. You can review '
                  'and edit every section before finalizing.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Note title (optional)',
                    hintText: 'e.g., Follow-up — diabetes review',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _patientController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Patient name or initials (optional)',
                    hintText: 'Stored encrypted on this device',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _languageCode,
                          decoration: const InputDecoration(
                            labelText: 'Consultation language',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final entry
                                in AppConfig.supportedLanguages.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _languageCode = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Used for speech recognition and the language of the '
                          'draft note.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _thinking,
                          onChanged: _busy ? null : _setThinking,
                          title: const Text('Thinking mode'),
                          subtitle: const Text(
                            'Off by default. Takes noticeably longer, but can '
                            'help with complex notes.',
                          ),
                          secondary: const Icon(Icons.psychology_outlined),
                        ),
                        if (_thinking)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              AppConfig.thinkingModeWarning,
                              style: TextStyle(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: _busy ? null : () => _createNote(record: true),
                  icon: const Icon(Icons.mic),
                  label: const Text('Record consultation'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _createNote(record: false),
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('Type or paste transcript'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 20),
                _HowItWorks(theme: theme),
                const SizedBox(height: 16),
                Text(
                  AppConfig.privacySummary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How it works',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _Step(
              number: '1',
              text: 'Record or type the consultation transcript.',
              theme: theme,
            ),
            _Step(
              number: '2',
              text:
                  'The on-device speech model transcribes the audio. The '
                  'recording is then deleted.',
              theme: theme,
            ),
            _Step(
              number: '3',
              text:
                  'The local language model drafts the six clinical sections '
                  'for you to review and edit.',
              theme: theme,
            ),
            _Step(
              number: '4',
              text: 'Finalize the note. It remains encrypted on this device.',
              theme: theme,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.text,
    required this.theme,
    this.isLast = false,
  });

  final String number;
  final String text;
  final ThemeData theme;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
