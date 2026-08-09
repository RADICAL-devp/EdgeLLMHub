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
    String rawText = 'Patient reports persistent cough.',
    String? richTextDelta,
  }) {
    return DoctorNote(
      noteId: 'note-$consultationId',
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
}
