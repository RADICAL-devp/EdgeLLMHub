import 'package:flutter/material.dart';
import 'package:doctor_app/core/models/download_progress.dart';
import 'package:doctor_app/core/services/model_download_service.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String modelName;
  final String modelSize;

  const DownloadProgressDialog({
    super.key,
    required this.modelName,
    required this.modelSize,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  @override
  void dispose() {
    ModelDownloadService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Downloading ${widget.modelName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<DownloadProgress>(
          stream: ModelDownloadService().progressStream,
          builder: (context, snapshot) {
            final progress = snapshot.data;
            if (progress == null) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting download...'),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress.progress),
                const SizedBox(height: 16),
                Text(
                  '${(progress.progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatBytes(progress.bytesDownloaded)} / ${widget.modelSize}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (progress.status == 'verifying') ...[
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Verifying checksum...'),
                    ],
                  ),
                ],
                if (progress.status == 'extracting') ...[
                  const SizedBox(height: 8),
                  const Text('Extracting model...'),
                ],
                if (progress.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${progress.errorMessage}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
