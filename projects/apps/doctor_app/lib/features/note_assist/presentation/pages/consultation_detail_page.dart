import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:doctor_app/core/models/consultation_transcript.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/models/transcript_summary_bundle.dart';
import 'package:doctor_app/core/ports/transcript_repository.dart';
import 'package:doctor_app/core/ports/transcript_summary_repository.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'note_editor_page.dart';

/// Read-only overview of a consultation: patient context, raw transcript,
/// the AI-generated structured summary, and extracted clinical fields.
class ConsultationDetailPage extends StatelessWidget {
  final String consultationId;
  final String patientId;
  final String doctorId;

  const ConsultationDetailPage({
    super.key,
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consultation Details'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Doctor Notes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ConsultationOverview(
              consultationId: consultationId,
              patientId: patientId,
              doctorId: doctorId,
            ),
            NoteEditorPage(
              consultationId: consultationId,
              patientId: patientId,
              doctorId: doctorId,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultationOverview extends StatefulWidget {
  final String consultationId;
  final String patientId;
  final String doctorId;

  const _ConsultationOverview({
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
  });

  @override
  State<_ConsultationOverview> createState() => _ConsultationOverviewState();
}

class _ConsultationOverviewState extends State<_ConsultationOverview> {
  late Future<_OverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<_OverviewData> _load() async {
    final transcriptRepo = GetIt.I<TranscriptRepository>();
    final summaryRepo = GetIt.I<TranscriptSummaryRepository>();
    final localRepo = GetIt.I<NoteLocalRepository>();

    final transcript =
        await transcriptRepo.findByConsultationId(widget.consultationId);
    TranscriptSummaryBundle? bundle;
    try {
      bundle = await summaryRepo.findByConsultationId(widget.consultationId);
    } catch (_) {
      // Structured summary may not yet exist — this is expected.
    }
    DoctorNote? note;
    try {
      note = await localRepo.getNoteByConsultationId(widget.consultationId);
    } catch (_) {
      // Notes may not exist yet.
    }

    return _OverviewData(
      consultationId: widget.consultationId,
      patientId: widget.patientId,
      doctorId: widget.doctorId,
      transcript: transcript,
      bundle: bundle,
      note: note,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OverviewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _OverviewError(
            message: '${snapshot.error}',
            onRetry: _reload,
          );
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _ContextCard(data: data),
              if (data.transcript != null)
                _TranscriptCard(transcript: data.transcript!)
              else
                const _EmptyCard(
                  icon: Icons.graphic_eq,
                  title: 'No transcript yet',
                  subtitle: 'Transcript data will appear here once available.',
                ),
              if (data.bundle?.structuredMedicalSummary != null)
                _StructuredSummaryCard(
                  summary: data.bundle!.structuredMedicalSummary!,
                  complete: data.bundle!.structuredMedicalSummary!.isComplete,
                ),
              if (data.bundle?.doctorNote != null)
                _AiDoctorNoteCard(
                  noteText: data.bundle!.doctorNote!.cleanedText ??
                      data.bundle!.doctorNote!.rawText ??
                      '',
                ),
              if (data.note?.extractedFields != null)
                _ExtractedFieldsCard(fields: data.note!.extractedFields!),
              if (_hasNoData(data))
                const _EmptyCard(
                  icon: Icons.medical_information_outlined,
                  title: 'Nothing here yet',
                  subtitle:
                      'Transcripts and AI summaries will show up here once '
                      'a consultation is processed.',
                ),
            ],
          ),
        );
      },
    );
  }

  bool _hasNoData(_OverviewData data) =>
      data.transcript == null &&
      data.bundle?.structuredMedicalSummary == null &&
      data.bundle?.doctorNote == null &&
      data.note?.extractedFields == null;
}

class _OverviewData {
  final String consultationId;
  final String patientId;
  final String doctorId;
  final ConsultationTranscript? transcript;
  final TranscriptSummaryBundle? bundle;
  final DoctorNote? note;

  const _OverviewData({
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
    this.transcript,
    this.bundle,
    this.note,
  });
}

class _ContextCard extends StatelessWidget {
  final _OverviewData data;

  const _ContextCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Consultation Timeline',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Consultation', value: data.consultationId),
            _InfoRow(label: 'Patient', value: data.patientId),
            _InfoRow(label: 'Doctor', value: data.doctorId),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final ConsultationTranscript transcript;

  const _TranscriptCard({required this.transcript});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Row(
          children: [
            Icon(Icons.graphic_eq),
            SizedBox(width: 8),
            Text('Raw Transcript'),
          ],
        ),
        subtitle: Text(
          'Recorded ${_formatDate(transcript.createdAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(transcript.transcriptText),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? time) {
    if (time == null) return 'unknown time';
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} at $hh:$mm';
  }
}

class _StructuredSummaryCard extends StatelessWidget {
  final StructuredSummary summary;
  final bool complete;

  const _StructuredSummaryCard({
    required this.summary,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: complete ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Structured AI Summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  complete ? 'COMPLETE' : 'RECOMMENDED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: complete ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (summary.complaint != null)
              _SummaryField(label: 'Chief Complaint', value: summary.complaint!),
            if (summary.pastHistory != null)
              _SummaryField(label: 'Past History', value: summary.pastHistory!),
            if (summary.vitals != null)
              _SummaryField(label: 'Vitals', value: summary.vitals!),
            if (summary.physicalExamination != null)
              _SummaryField(
                  label: 'Physical Examination',
                  value: summary.physicalExamination!),
            if (summary.investigationOrdered != null)
              _SummaryField(
                  label: 'Investigations Ordered',
                  value: summary.investigationOrdered!),
            if (summary.diagnosis != null)
              _SummaryField(label: 'Diagnosis', value: summary.diagnosis!),
            if (summary.advice != null)
              _SummaryField(label: 'Advice', value: summary.advice!),
          ],
        ),
      ),
    );
  }
}

class _SummaryField extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AiDoctorNoteCard extends StatelessWidget {
  final String noteText;

  const _AiDoctorNoteCard({required this.noteText});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'AI-Generated Doctor Note',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              noteText.isEmpty ? '(empty)' : noteText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractedFieldsCard extends StatelessWidget {
  final ExtractedFields fields;

  const _ExtractedFieldsCard({required this.fields});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      if (fields.provisionalDiagnosis != null)
        ('Provisional Diagnosis', fields.provisionalDiagnosis!),
      if (fields.duration != null) ('Duration', fields.duration!),
      if (fields.symptoms.isNotEmpty)
        ('Symptoms', fields.symptoms.join(', ')),
      if (fields.medications.isNotEmpty)
        ('Medications', fields.medications.join(', ')),
      if (fields.allergies.isNotEmpty)
        ('Allergies', fields.allergies.join(', ')),
      if (fields.testsRecommended.isNotEmpty)
        ('Tests Recommended', fields.testsRecommended.join(', ')),
      if (fields.followUpActions.isNotEmpty)
        ('Follow-up Actions', fields.followUpActions.join(', ')),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.data_object, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Extracted Fields',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => _SummaryField(label: item.$1, value: item.$2),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OverviewError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Failed to load overview: $message',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}