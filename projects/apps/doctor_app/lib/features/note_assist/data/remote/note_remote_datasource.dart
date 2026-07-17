import 'package:dio/dio.dart';
import '../../domain/models/doctor_note.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/network/dio_error_handler.dart';

/// Remote datasource for syncing notes to the backend API.
///
/// Uses [DioErrorHandler] to map all Dio failures to typed
/// [NetworkException] with transience metadata.
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
        'extractedFields': note.extractedFields?.toJson(),
        'recap': note.patientRecap,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
      };

      await _dio.post(
        '/api/doctor-notes/sync',
        data: payload,
      );
    } on DioException catch (e) {
      throw DioErrorHandler.handle(e, context: 'syncNote');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        'Unexpected error syncing note: $e',
        cause: e,
        isTransient: true,
      );
    }
  }

  Future<DoctorNote?> fetchNoteForConsultation(String consultationId) async {
    try {
      final response =
          await _dio.get('/api/doctor-notes/consultation/$consultationId');
      if (response.data != null) {
        // Parse logic would go here
        return null; // For simplicity in this scaffold
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // Not found is an expected case
      }
      throw DioErrorHandler.handle(e, context: 'fetchNote');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        'Failed to fetch note: $e',
        cause: e,
        isTransient: true,
      );
    }
  }
}
