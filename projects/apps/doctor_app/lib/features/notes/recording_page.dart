import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/data/note_repository.dart';
import '../../core/models/clinical_note.dart';
import '../../core/services/audio_capture_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/responsive.dart';
import '../../core/utils/formatters.dart';
import 'cubits/note_editor_cubit.dart';
import 'cubits/note_editor_state.dart';
import 'cubits/recording_cubit.dart';
import 'cubits/recording_state.dart';
import 'widgets/error_banner.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key, required this.noteId});

  final String noteId;

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  NoteEditorCubit? _noteCubit;
  RecordingCubit? _recordingCubit;
  bool _loading = true;
  bool _hasSavedTranscript = false;
  bool _sttReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final noteCubit = NoteEditorCubit(repository: GetIt.I<NoteRepository>());
    try {
      final note = await noteCubit.load(widget.noteId);
      if (!mounted) {
        await noteCubit.close();
        return;
      }
      if (note == null) {
        setState(() {
          _loading = false;
          _error = 'This note could not be found.';
        });
        await noteCubit.close();
        return;
      }

      final recordingCubit = RecordingCubit(
        audio: GetIt.I<AudioCaptureService>(),
        transcription: GetIt.I<TranscriptionService>(),
        languageCode: note.languageCode,
      );

      setState(() {
        _noteCubit = noteCubit;
        _recordingCubit = recordingCubit;
        _sttReady = GetIt.I<TranscriptionService>().isReady;
        _loading = false;
      });
    } catch (_) {
      await noteCubit.close();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The recording screen could not load this note.';
      });
    }
  }

  Future<void> _saveTranscript(RecordingState state) async {
    if (_hasSavedTranscript) return;
    _hasSavedTranscript = true;
    final noteCubit = _noteCubit;
    if (noteCubit == null || state.transcript.trim().isEmpty) return;

    noteCubit.updateTranscript(state.transcript);
    await noteCubit.saveNow();
    if (!mounted) return;
    context.go(AppRoutes.transcript(widget.noteId));
  }

  @override
  void dispose() {
    _recordingCubit?.close();
    _noteCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _noteCubit == null || _recordingCubit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record consultation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(_error ?? 'The recording screen is unavailable.'),
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

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _noteCubit!),
        BlocProvider.value(value: _recordingCubit!),
      ],
      child: _RecordingView(
        noteId: widget.noteId,
        sttReady: _sttReady,
        onTranscriptReady: _saveTranscript,
      ),
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({
    required this.noteId,
    required this.sttReady,
    required this.onTranscriptReady,
  });

  final String noteId;
  final bool sttReady;
  final Future<void> Function(RecordingState state) onTranscriptReady;

  Future<void> _handleBack(BuildContext context) async {
    final cubit = context.read<RecordingCubit>();
    final state = cubit.state;

    if (state.phase == RecordingPhase.transcribing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait for the on-device transcription to finish.',
          ),
        ),
      );
      return;
    }

    if (state.phase == RecordingPhase.recording ||
        state.phase == RecordingPhase.paused) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this recording?'),
          content: const Text(
            'The temporary audio will be deleted and the transcript will not '
            'be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep recording'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
      await cubit.cancel();
      if (!context.mounted) return;
    } else {
      await cubit.cancel();
      if (!context.mounted) return;
    }
    context.go(AppRoutes.note(noteId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<RecordingCubit, RecordingState>(
      listenWhen: (previous, current) =>
          current.phase == RecordingPhase.done &&
          previous.phase != RecordingPhase.done,
      listener: (context, state) => onTranscriptReady(state),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await _handleBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Record consultation'),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => _handleBack(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: CenteredContent(
                maxWidth: 640,
                child: BlocBuilder<NoteEditorCubit, NoteEditorState>(
                  builder: (context, noteState) {
                    final note = noteState is NoteEditorLoaded
                        ? noteState.note
                        : null;
                    return BlocBuilder<RecordingCubit, RecordingState>(
                      builder: (context, state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(note: note),
                            if (note != null &&
                                note.transcript.trim().isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: _Notice(
                                  icon: Icons.swap_horiz,
                                  text:
                                      'Saving a new transcript will replace the '
                                      'existing transcript for this note.',
                                ),
                              ),
                            const SizedBox(height: 20),
                            _RecorderCard(state: state),
                            const SizedBox(height: 16),
                            if (state.error != null)
                              ErrorBanner(message: state.error!),
                            if (state.needsModelSetup && !sttReady)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _Notice(
                                  icon: Icons.download_for_offline_outlined,
                                  text:
                                      'The on-device speech model is not '
                                      'installed. Download it from setup to '
                                      'record.',
                                  action: TextButton(
                                    onPressed: () =>
                                        context.go(AppRoutes.setup),
                                    child: const Text('Set up AI'),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 18),
                            _Actions(
                              state: state,
                              sttReady: sttReady,
                              noteId: noteId,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Audio is captured at 16 kHz mono and deleted '
                              'immediately after on-device transcription. '
                              'Nothing is uploaded.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.note});

  final ClinicalNote? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note?.displayTitle ?? 'Consultation';
    final patient = note?.displayPatient ?? 'No patient name';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'On-device recording',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          patient,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RecorderCard extends StatelessWidget {
  const _RecorderCard({required this.state});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recording = state.isRecording;
    final paused = state.isPaused;
    final transcribing = state.isTranscribing;
    final active = recording || paused || transcribing;
    final color = recording
        ? theme.colorScheme.error
        : paused
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                transcribing
                    ? Icons.auto_awesome
                    : recording
                    ? Icons.mic
                    : paused
                    ? Icons.pause
                    : Icons.mic_none,
                size: 42,
                color: color,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              label: 'Recording duration ${formatDuration(state.elapsed)}',
              child: Text(
                formatDuration(state.elapsed),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (active)
              _Waveform(amplitude: recording ? state.amplitude : 0)
            else
              const SizedBox(height: 46),
            const SizedBox(height: 12),
            Text(
              _statusText(state),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: state.phase == RecordingPhase.error
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (transcribing) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: state.progress > 0 && state.progress < 1
                    ? state.progress
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                state.segmentCount > 0
                    ? 'Segment ${state.segmentIndex} of ${state.segmentCount} · '
                          '${(state.progress * 100).round()}%'
                    : 'Preparing the on-device speech model…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _statusText(RecordingState state) {
    switch (state.phase) {
      case RecordingPhase.idle:
        return 'Ready when you are. Find a quiet place and speak naturally.';
      case RecordingPhase.preparing:
        return 'Preparing the microphone…';
      case RecordingPhase.recording:
        return 'Recording — audio is processed on this device.';
      case RecordingPhase.paused:
        return 'Paused. Resume when you are ready.';
      case RecordingPhase.transcribing:
        return 'Transcribing on this device. Keep the app open for a moment.';
      case RecordingPhase.done:
        return 'Transcript ready. Saving…';
      case RecordingPhase.error:
        return state.error ?? 'Recording stopped.';
    }
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.amplitude});

  final double amplitude;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 27; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 4,
                height:
                    6 +
                    amplitude * 34 * (0.35 + 0.65 * math.sin(i * 1.3).abs()),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55 + amplitude * 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.sttReady,
    required this.noteId,
  });

  final RecordingState state;
  final bool sttReady;
  final String noteId;

  Future<void> _start(BuildContext context) async {
    final cubit = context.read<RecordingCubit>();
    cubit.reset();
    await cubit.start();
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecordingCubit>();

    switch (state.phase) {
      case RecordingPhase.idle:
      case RecordingPhase.preparing:
        return FilledButton.icon(
          onPressed: state.phase == RecordingPhase.preparing
              ? null
              : () => _start(context),
          icon: state.phase == RecordingPhase.preparing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mic),
          label: const Text('Start recording'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        );
      case RecordingPhase.recording:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cubit.pause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: cubit.stopAndTranscribe,
                icon: const Icon(Icons.stop),
                label: const Text('Stop & transcribe'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        );
      case RecordingPhase.paused:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cubit.resume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: cubit.stopAndTranscribe,
                icon: const Icon(Icons.stop),
                label: const Text('Stop & transcribe'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        );
      case RecordingPhase.transcribing:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Transcription cannot be interrupted. Please keep the app open.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case RecordingPhase.done:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Saving transcript…'),
              ],
            ),
          ),
        );
      case RecordingPhase.error:
        final needsSetup = state.needsModelSetup || !sttReady;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (needsSetup)
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.setup),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('Set up the speech model'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              )
            else if (state.permissionDenied)
              FilledButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open system settings'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              )
            else
              FilledButton.icon(
                onPressed: () => _start(context),
                icon: const Icon(Icons.refresh),
                label: const Text('Try recording again'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.transcript(noteId)),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Type transcript instead'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        );
    }
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
