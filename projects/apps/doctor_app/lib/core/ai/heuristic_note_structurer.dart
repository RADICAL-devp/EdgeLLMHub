import 'package:shared_models/shared_models.dart';

/// A deliberately minimal, non-AI scaffold used only when the model cannot
/// produce a note.
///
/// It copies the first sentence into the chief complaint and the transcript
/// into the HPI so the clinician has the source material in the editor. It
/// never fabricates an assessment, examination, plan, or follow-up.
class HeuristicNoteStructurer {
  const HeuristicNoteStructurer();

  StructuredNoteSections scaffold(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) return StructuredNoteSections();

    final sentences = text.split(RegExp(r'(?<=[.!?।])\s+'));
    final first = sentences.first.trim().isEmpty
        ? text
        : sentences.first.trim();
    final complaint = first.length > 240
        ? '${first.substring(0, 240)}…'
        : first;

    return StructuredNoteSections(
      chiefComplaint: complaint,
      historyOfPresentIllness: text,
    );
  }
}
