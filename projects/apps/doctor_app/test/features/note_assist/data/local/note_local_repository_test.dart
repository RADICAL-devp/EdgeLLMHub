import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase db;
  late NoteLocalRepository repository;

  setUp(() {
    db = LocalDatabase.connect(NativeDatabase.memory());
    repository = NoteLocalRepository(db);
  });

  tearDown(() async => db.close());

  DoctorNote note({
    required String consultationId,
    String? noteId,
    String rawText = 'Patient reports persistent cough.',
    String? richTextDelta,
  }) {
    return DoctorNote(
      noteId: noteId ?? 'note-$consultationId',
      consultationId: consultationId,
      patientId: 'p-$consultationId',
      doctorId: 'd1',
      rawText: rawText,
      richTextDelta: richTextDelta,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('saveNote persists the rich-text delta', () async {
    const deltaJson =
        '[{"insert":"Patient reports"},{"insert":" persistent","attributes":{"bold":true}},{"insert":" cough.\\n"}]';
    await repository.saveNote(
      note(consultationId: 'c1', richTextDelta: deltaJson),
    );

    final saved = await repository.getNoteByConsultationId('c1');
    expect(saved, isNotNull);
    expect(saved!.richTextDelta, deltaJson);
    expect(saved.rawText, 'Patient reports persistent cough.');
  });

  test('note without delta round-trips with null richTextDelta', () async {
    await repository.saveNote(note(consultationId: 'c2'));

    final saved = await repository.getNoteByConsultationId('c2');
    expect(saved, isNotNull);
    expect(saved!.richTextDelta, isNull);
    expect(saved.rawText, 'Patient reports persistent cough.');
  });

  test('updating a note replaces the delta', () async {
    await repository.saveNote(note(consultationId: 'c3'));
    final updated = note(
      consultationId: 'c3',
      richTextDelta: '[{"insert":"New delta content.\\n"}]',
    );

    await repository.saveNote(updated);

    final saved = await repository.getNoteByConsultationId('c3');
    expect(saved!.richTextDelta, '[{"insert":"New delta content.\\n"}]');
  });

  test('DoctorNote JSON serialization includes richTextDelta', () {
    final note = DoctorNote(
      noteId: 'n1',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: 'Hello',
      richTextDelta: '[{"insert":"Hello\\n"}]',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final roundTripped =
        DoctorNote.fromJson(note.toJson());

    expect(roundTripped.richTextDelta, '[{"insert":"Hello\\n"}]');
    expect(roundTripped.rawText, 'Hello');
  });

  test('getNoteById returns the matching note', () async {
    await repository.saveNote(note(consultationId: 'c1'));
    final saved = await repository.getNoteByConsultationId('c1');

    final found = await repository.getNoteById(saved!.noteId);
    expect(found, isNotNull);
    expect(found!.consultationId, 'c1');
  });

  test('getNoteById returns null for unknown note', () async {
    final found = await repository.getNoteById('does-not-exist');
    expect(found, isNull);
  });

  test('extracted fields and patient recap round-trip', () async {
    final withFields = DoctorNote(
      noteId: 'note-c4',
      consultationId: 'c4',
      patientId: 'p4',
      doctorId: 'd1',
      rawText: 'Cough, fever.',
      extractedFields: const ExtractedFields(
        symptoms: ['cough', 'fever'],
        provisionalDiagnosis: 'Upper respiratory infection',
        medications: ['paracetamol'],
      ),
      patientRecap: 'Returns for follow-up in 2 weeks.',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await repository.saveNote(withFields);

    final saved = await repository.getNoteByConsultationId('c4');
    expect(saved!.extractedFields, isNotNull);
    expect(saved.extractedFields!.symptoms, ['cough', 'fever']);
    expect(saved.extractedFields!.provisionalDiagnosis,
        'Upper respiratory infection');
    expect(saved.patientRecap, 'Returns for follow-up in 2 weeks.');
  });

  test('getAllNotes orders newest first', () async {
    await repository.saveNote(
      note(consultationId: 'old', rawText: 'old note')
          .copyWith(updatedAt: DateTime(2026, 1, 1)),
    );
    await repository.saveNote(
      note(consultationId: 'new', rawText: 'new note')
          .copyWith(updatedAt: DateTime(2026, 1, 3)),
    );

    final all = await repository.getAllNotes();
    expect(all.map((n) => n.consultationId).toList(), ['new', 'old']);
  });

  test('getAllConsultations keeps only the latest note per consultation',
      () async {
    await repository.saveNote(
      note(consultationId: 'c1', rawText: 'first draft')
          .copyWith(updatedAt: DateTime(2026, 1, 1)),
    );
    await repository.saveNote(
      note(consultationId: 'c1', rawText: 'final draft')
          .copyWith(updatedAt: DateTime(2026, 1, 2)),
    );

    final consultations = await repository.getAllConsultations();
    expect(consultations, hasLength(1));
    expect(consultations.single.rawText, 'final draft');
  });

  test('getNotesForConsultation returns all notes for a consultation',
      () async {
    await repository.saveNote(
      note(consultationId: 'c1', noteId: 'note-c1-v1', rawText: 'first')
          .copyWith(updatedAt: DateTime(2026, 1, 1)),
    );
    await repository.saveNote(
      note(consultationId: 'c1', noteId: 'note-c1-v2', rawText: 'second')
          .copyWith(updatedAt: DateTime(2026, 1, 2)),
    );
    await repository.saveNote(
      note(consultationId: 'other', rawText: 'unrelated'),
    );

    final notes = await repository.getNotesForConsultation('c1');
    expect(notes, hasLength(2));
  });
}
