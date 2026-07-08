import 'consultation_mode.dart';

/// A stored consultation transcript.
///
/// Represents the raw transcribed text from a clinical consultation,
/// along with metadata about the consultation context.
class ConsultationTranscript {
  ConsultationTranscript({
    required this.transcriptId,
    required this.consultationId,
    this.patientId,
    this.doctorId,
    this.sleepLabId,
    required this.transcriptText,
    this.consultationMode,
    this.segments = const [],
    this.createdAt,
  });

  final String transcriptId;
  final String consultationId;
  final String? patientId;
  final String? doctorId;
  final String? sleepLabId;
  final String transcriptText;
  final ConsultationMode? consultationMode;
  final List<TranscriptSegment> segments;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'transcriptId': transcriptId,
        'consultationId': consultationId,
        'patientId': patientId,
        'doctorId': doctorId,
        'sleepLabId': sleepLabId,
        'transcriptText': transcriptText,
        'consultationMode': consultationMode?.toJson(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };
}

/// A segment of a transcript, optionally tagged with a speaker.
class TranscriptSegment {
  TranscriptSegment({
    required this.index,
    required this.text,
    this.speaker,
    this.timestampStart,
    this.timestampEnd,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      index: json['index'] as int,
      text: json['text'] as String,
      speaker: json['speaker'] as String?,
      timestampStart: json['timestampStart'] as String?,
      timestampEnd: json['timestampEnd'] as String?,
    );
  }

  final int index;
  final String text;
  final String? speaker;
  final String? timestampStart;
  final String? timestampEnd;

  Map<String, dynamic> toJson() => {
        'index': index,
        'text': text,
        'speaker': speaker,
        'timestampStart': timestampStart,
        'timestampEnd': timestampEnd,
      };
}
