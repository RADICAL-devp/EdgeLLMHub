import 'package:dio/dio.dart';
import '../../domain/models/doctor_note.dart';
import 'dart:convert';

class NoteRemoteDatasource {
  final Dio _dio;

  NoteRemoteDatasource(this._dio);

  Future<void> syncNote(DoctorNote note) async {
    try {
      final payload = {
        'noteId': note.noteId,
        'consultationId': note.consultationId,
        'patientId': note.patientId,
        'doctorId': note.doctorId,
        'rawText': note.rawText,
        'status': note.status.name,
        'extractedFields': note.extractedFields != null ? note.extractedFields!.toJson() : null,
        'recap': note.patientRecap,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
      };

      await _dio.post(
        '/api/doctor-notes/sync',
        data: payload,
      );
    } catch (e) {
      throw Exception('Failed to sync note: $e');
    }
  }

  Future<DoctorNote?> fetchNoteForConsultation(String consultationId) async {
    try {
      final response = await _dio.get('/api/doctor-notes/consultation/$consultationId');
      if (response.data != null) {
        // Parse logic would go here
        return null; // For simplicity in this scaffold
      }
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to fetch note: $e');
    }
  }
}
