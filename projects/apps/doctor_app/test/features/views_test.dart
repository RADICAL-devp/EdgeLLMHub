import 'package:doctor_app/app.dart';
import 'package:doctor_app/core/models/clinical_note.dart';
import 'package:doctor_app/core/models/model_install_progress.dart';
import 'package:doctor_app/features/dashboard/dashboard_cubit.dart';
import 'package:doctor_app/features/dashboard/dashboard_page.dart';
import 'package:doctor_app/features/notes/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

ClinicalNote _note() {
  return ClinicalNote(
    id: 'one',
    title: 'Chest pain review',
    patientName: 'Asha Rao',
    transcript: 'Patient reports chest pain since yesterday.',
    sections: StructuredNoteSections(
      chiefComplaint: 'Chest pain',
      assessment: 'Possible angina',
    ),
    status: NoteStatus.draft,
    languageCode: 'en',
    createdAt: DateTime(2020, 1, 2, 9, 30),
    updatedAt: DateTime(2020, 1, 2, 9, 30),
  );
}

void main() {
  testWidgets('dashboard view renders accessible summaries', (tester) async {
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = DashboardState(
      totalNotes: 1,
      drafts: 1,
      finalized: 0,
      updatedToday: 0,
      recentNotes: [_note()],
      modelStatus: const ModelStatus(
        llmReady: true,
        sttReady: true,
        storageMb: 433,
      ),
      isLoading: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: DashboardView(
            state: state,
            onRefresh: () async {},
            onNewNote: () {},
            onSearch: () {},
            onSeeAllNotes: () {},
            onSetup: () {},
            onOpenNote: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private, on-device documentation'), findsOneWidget);
    expect(find.text('Chest pain review'), findsOneWidget);
    expect(find.text('No patient name'), findsNothing);
  });

  testWidgets('note card exposes a button semantics label', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(note: _note(), onTap: () => tapped = true),
        ),
      ),
    );

    final handle = tester.ensureSemantics();
    await tester.pumpAndSettle();

    final semantics =
        find.byType(NoteCard).evaluate().single.widget as NoteCard;
    expect(semantics.note.displayTitle, 'Chest pain review');
    expect(semantics.note.displayPatient, 'Asha Rao');

    await tester.tap(find.byType(NoteCard));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    handle.dispose();
  });
}
