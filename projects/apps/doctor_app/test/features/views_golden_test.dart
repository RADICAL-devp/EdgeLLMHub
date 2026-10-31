import 'package:doctor_app/app.dart';
import 'package:doctor_app/core/models/clinical_note.dart';
import 'package:doctor_app/core/models/model_install_progress.dart';
import 'package:doctor_app/features/dashboard/dashboard_cubit.dart';
import 'package:doctor_app/features/dashboard/dashboard_page.dart';
import 'package:doctor_app/features/notes/cubits/notes_state.dart';
import 'package:doctor_app/features/notes/notes_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

ClinicalNote _note({
  required String id,
  required String title,
  required String patient,
  NoteStatus status = NoteStatus.draft,
}) {
  return ClinicalNote(
    id: id,
    title: title,
    patientName: patient,
    transcript: 'Patient reports chest pain since yesterday.',
    sections: StructuredNoteSections(
      chiefComplaint: 'Chest pain',
      assessment: 'Possible angina',
    ),
    status: status,
    languageCode: 'en',
    createdAt: DateTime(2020, 1, 2, 9, 30),
    updatedAt: DateTime(2020, 1, 2, 9, 30),
  );
}

Widget _app(Widget body) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: Scaffold(body: body),
  );
}

void main() {
  testWidgets('dashboard view matches the golden', (tester) async {
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = DashboardState(
      totalNotes: 3,
      drafts: 2,
      finalized: 1,
      updatedToday: 1,
      recentNotes: [
        _note(id: 'one', title: 'Chest pain review', patient: 'Asha Rao'),
        _note(
          id: 'two',
          title: 'Follow-up',
          patient: 'Ravi Kumar',
          status: NoteStatus.finalized,
        ),
      ],
      modelStatus: const ModelStatus(
        llmReady: true,
        sttReady: true,
        storageMb: 433,
      ),
      isLoading: false,
    );

    await tester.pumpWidget(
      _app(
        DashboardView(
          state: state,
          onRefresh: () async {},
          onNewNote: () {},
          onSearch: () {},
          onSeeAllNotes: () {},
          onSetup: () {},
          onOpenNote: (_) {},
          now: DateTime(2026, 10, 29, 9),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_view.png'),
    );
  });

  testWidgets('notes list matches the golden', (tester) async {
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = NotesState(
      notes: [
        _note(id: 'one', title: 'Chest pain review', patient: 'Asha Rao'),
        _note(
          id: 'two',
          title: 'Follow-up',
          patient: 'Ravi Kumar',
          status: NoteStatus.finalized,
        ),
        _note(id: 'three', title: '', patient: ''),
      ],
    );

    await tester.pumpWidget(
      _app(
        NotesView(
          state: state,
          onRefresh: () async {},
          onFilterChanged: (_) {},
          onOpenNote: (_) {},
          onDeleteNote: (_) {},
          onNewNote: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(NotesView),
      matchesGoldenFile('goldens/notes_view.png'),
    );
  });
}
