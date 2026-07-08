import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/model_manager_cubit.dart';

class ModelManagerPage extends StatelessWidget {
  const ModelManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ModelManagerCubit()..checkModelExists(),
      child: Scaffold(
        appBar: AppBar(title: const Text('AI Model Manager')),
        body: Center(
          child: BlocBuilder<ModelManagerCubit, ModelManagerState>(
            builder: (context, state) {
              if (state is ModelManagerInitial) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_download, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('On-device AI model is not installed.'),
                    const SizedBox(height: 8),
                    const Text(
                      'Download the Gemma 2B model (~2GB) to enable offline AI assistance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.read<ModelManagerCubit>().downloadModel(),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Model'),
                    ),
                  ],
                );
              } else if (state is ModelManagerDownloading) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(value: state.progress),
                    const SizedBox(height: 16),
                    Text('Downloading... ${(state.progress * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 8),
                    const Text('Please keep the app open.', style: TextStyle(color: Colors.grey)),
                  ],
                );
              } else if (state is ModelManagerReady) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text('AI Model is installed and ready.'),
                    const SizedBox(height: 8),
                    Text(
                      'Path: ${state.modelPath}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/consultation/c123/patient/p456/doctor/d789'),
                      child: const Text('Continue to Editor'),
                    ),
                  ],
                );
              } else if (state is ModelManagerError) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${state.message}', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => context.read<ModelManagerCubit>().checkModelExists(),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
