import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import '../cubit/model_manager_cubit.dart';

class ModelManagerPage extends StatelessWidget {
  const ModelManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ModelManagerCubit(
        capabilityService: GetIt.I<DeviceCapabilityService>(),
        downloader: DioModelDownloader(dio: GetIt.I<Dio>()),
      )..checkModelExists(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Model Manager'),
          actions: [
            IconButton(
              tooltip: 'Consultations',
              onPressed: () => context.go('/consultations'),
              icon: const Icon(Icons.notes),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: Center(
          child: BlocBuilder<ModelManagerCubit, ModelManagerState>(
            builder: (context, state) {
              if (state is ModelManagerInitial) {
                return _buildNotInstalled(context);
              } else if (state is ModelManagerDownloading) {
                return _buildDownloading(context, state);
              } else if (state is ModelManagerReady) {
                return _buildReady(context, state);
              } else if (state is ModelManagerError) {
                return _buildError(context, state);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotInstalled(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_download, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('On-device AI model is not installed.'),
          const SizedBox(height: 8),
          const Text(
            'Download the SmolLM-350M model (~350MB) to enable offline AI '
            'assistance. The model runs entirely on-device — no PHI leaves '
            'the device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                context.read<ModelManagerCubit>().downloadModel(),
            icon: const Icon(Icons.download),
            label: const Text('Download Model'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloading(
      BuildContext context, ModelManagerDownloading state) {
    final percent = (state.progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.isVerifying)
          const CircularProgressIndicator()
        else
          CircularProgressIndicator(value: state.progress),
        const SizedBox(height: 16),
        Text(
          '${state.isVerifying ? 'Verifying' : 'Downloading'}... $percent%',
          key: const Key('model_download_progress'),
        ),
        const SizedBox(height: 8),
        if (state.isVerifying)
          Text(
            state.phaseLabel,
            style: const TextStyle(color: Colors.grey),
          )
        else ...[
          Text(
            '${_formatBytes(state.downloadedBytes)} of '
            '${state.totalBytes > 0 ? _formatBytes(state.totalBytes) : '…'}',
            style: const TextStyle(color: Colors.grey),
          ),
          if (state.speedBytesPerSec > 0)
            Text(
              '${_formatBytes(state.speedBytesPerSec.toInt())}/s',
              style: const TextStyle(color: Colors.grey),
            ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Please keep the app open.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  Widget _buildReady(BuildContext context, ModelManagerReady state) {
    final modeColor = switch (state.executionMode) {
      'local' => Colors.green,
      'cloud' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text('AI model is installed and ready.'),
          const SizedBox(height: 8),
          Text(
            state.modelPath,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Chip(
            avatar: Icon(
              state.executionMode == 'local'
                  ? Icons.phone_android
                  : Icons.cloud_outlined,
              size: 16,
              color: modeColor,
            ),
            label: Text(
              'Execution mode: ${state.executionMode.toUpperCase()}',
              style: TextStyle(color: modeColor, fontWeight: FontWeight.w600),
            ),
          ),
          if (state.modelInfo != null) ...[
            const SizedBox(height: 12),
            _ModelInfoCard(info: state.modelInfo!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(
              '/consultation/c123/patient/p456/doctor/d789',
            ),
            child: const Text('Continue to Editor'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/consultations'),
            child: const Text('View Consultations'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, ModelManagerError state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 24),
          if (state.canRetry)
            OutlinedButton(
              onPressed: () =>
                  context.read<ModelManagerCubit>().checkModelExists(),
              child: const Text('Retry'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/consultations'),
            child: const Text('Continue to Consultations'),
          ),
        ],
      ),
    );
  }
}

class _ModelInfoCard extends StatelessWidget {
  final Map<String, Object?> info;

  const _ModelInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model details',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...info.entries.map(
              (entry) => _InfoRow(label: entry.key, value: '${entry.value}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}