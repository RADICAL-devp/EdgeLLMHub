import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_it/get_it.dart';
import '../../domain/services/note_assist_service.dart';
import '../../data/services/on_device_llm_service.dart';

abstract class ModelManagerState extends Equatable {
  const ModelManagerState();

  @override
  List<Object?> get props => [];
}

class ModelManagerInitial extends ModelManagerState {}

class ModelManagerDownloading extends ModelManagerState {
  final double progress; // 0.0 to 1.0

  const ModelManagerDownloading(this.progress);

  @override
  List<Object?> get props => [progress];
}

class ModelManagerReady extends ModelManagerState {
  final String modelPath;

  const ModelManagerReady(this.modelPath);

  @override
  List<Object?> get props => [modelPath];
}

class ModelManagerError extends ModelManagerState {
  final String message;

  const ModelManagerError(this.message);

  @override
  List<Object?> get props => [message];
}

class ModelManagerCubit extends Cubit<ModelManagerState> {
  final Dio _dio = Dio();
  static const String modelFileName = "gemma-2b-it.bin";
  
  // This is a dummy URL for simulation purposes. 
  // In a real app, this would be a signed URL to your GCP bucket.
  static const String modelDownloadUrl = "https://example.com/models/gemma-2b-it.bin";

  ModelManagerCubit() : super(ModelManagerInitial());

  Future<void> checkModelExists() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$modelFileName');

      if (await modelFile.exists()) {
        final llmService = GetIt.I<NoteAssistService>() as OnDeviceLlmService;
        await llmService.initialize(modelFile.path);
        emit(ModelManagerReady(modelFile.path));
      } else {
        emit(ModelManagerInitial());
      }
    } catch (e) {
      emit(ModelManagerError("Failed to check model: $e"));
    }
  }

  Future<void> downloadModel() async {
    try {
      emit(const ModelManagerDownloading(0.0));
      
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$modelFileName');

      // Simulate a large download since we don't have a real model URL in this environment.
      // In production:
      // await _dio.download(
      //   modelDownloadUrl,
      //   modelFile.path,
      //   onReceiveProgress: (received, total) {
      //     if (total != -1) {
      //       emit(ModelManagerDownloading(received / total));
      //     }
      //   },
      // );
      
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        emit(ModelManagerDownloading(i / 100.0));
      }

      // Create a dummy file so initialization doesn't immediately crash if it checks existence
      if (!await modelFile.exists()) {
        await modelFile.writeAsString("dummy_model_data");
      }

      final llmService = GetIt.I<NoteAssistService>() as OnDeviceLlmService;
      await llmService.initialize(modelFile.path);

      emit(ModelManagerReady(modelFile.path));
    } catch (e) {
      emit(ModelManagerError("Failed to download model: $e"));
    }
  }
}
