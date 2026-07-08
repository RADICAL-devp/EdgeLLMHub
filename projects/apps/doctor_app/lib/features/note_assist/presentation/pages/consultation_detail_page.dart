import 'package:flutter/material.dart';
import 'note_editor_page.dart';

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
            const Center(child: Text('Consultation Overview (Not Implemented)')),
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
