import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'package:doctor_app/features/note_assist/domain/services/diagnostics_exporter.dart';

/// App settings: privacy info (on-device processing only), device
/// capability info, and sync-queue diagnostics with log export.
///
/// Cloud processing is disabled by design — PHI must never leave the
/// device — so there is no cloud/consent toggle to expose.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loaded = false;
  ExecutionMode _recommendedMode = ExecutionMode.cloud;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final capability = GetIt.I<DeviceCapabilityService>();
    final recommended = await capability.getRecommendedExecutionMode();

    if (!mounted) return;
    setState(() {
      _recommendedMode = recommended;
      _loaded = true;
    });
  }

  Future<void> _exportLog() async {
    final syncQueue = GetIt.I<SyncQueueService>();
    final pending = await syncQueue.getPendingEntries();
    final dead = await syncQueue.getDeadLetterEntries();
    final capability = GetIt.I<DeviceCapabilityService>();
    final simulator = await capability.isSimulator;

    final buffer = StringBuffer()
      ..writeln('Doctor App Diagnostics Log')
      ..writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('----------------------------------------')
      ..writeln('Environment: ${EnvironmentConfig.environment.name}')
      ..writeln('API base URL: ${EnvironmentConfig.apiBaseUrl}')
      ..writeln(
        'Cloud LLM enabled (config): '
        '${EnvironmentConfig.cloudLlmEnabled} — disabled by design, '
        'PHI never leaves the device',
      )
      ..writeln('Recommended execution mode: ${_recommendedMode.name}')
      ..writeln('Is simulator: $simulator')
      ..writeln('Supported model: ${EnvironmentConfig.supportedModels.join(', ')}')
      ..writeln()
      ..writeln('Pending sync entries: ${pending.length}');

    buffer.writeln('Dead letter entries: ${dead.length}');
    buffer.writeln();
    for (final entry in pending) {
      buffer
        ..writeln('Pending: ${entry.noteId} op=${entry.operation} '
            'retry=${entry.retryCount}/${entry.maxRetries} '
            'error=${entry.lastError ?? '-'}')
        ..writeln();
    }
    for (final entry in dead) {
      buffer
        ..writeln('DEAD: ${entry.consultationId} op=${entry.operation} '
            'error=${entry.lastError ?? '-'}')
        ..writeln();
    }

    final filePath =
        await GetIt.I<DiagnosticsExporter>().exportLog(buffer.toString());

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: 'Clinical Intelligence diagnostics log',
        ),
      );
      messenger.showSnackBar(SnackBar(
        content: Text('Diagnostics exported to $filePath'),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Exported to $filePath (share unavailable)'),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _syncNow() async {
    final syncQueue = GetIt.I<SyncQueueService>();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Syncing…')));
    await syncQueue.syncNow();
    setState(() {});
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Sync complete.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Privacy & Processing'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('On-device processing only'),
            subtitle: Text(
              'All AI runs locally on this device. PHI never leaves the '
              'device — cloud processing is disabled by design.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Recommended execution mode'),
            subtitle: Text(_recommendedMode.name.toUpperCase()),
          ),
          const Divider(),
          const _SectionHeader('Sync Queue'),
          FutureBuilder<int>(
            future: GetIt.I<SyncQueueService>().getPendingCount(),
            builder: (context, snapshot) {
              return ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Pending syncs'),
                subtitle: Text('${snapshot.data ?? '…'} items waiting'),
              );
            },
          ),
          FutureBuilder<List<SyncQueueEntry>>(
            future: GetIt.I<SyncQueueService>().getDeadLetterEntries(),
            builder: (context, snapshot) {
              final dead = snapshot.data ?? const <SyncQueueEntry>[];
              return ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Dead letter queue'),
                subtitle: Text('${dead.length} failed permanently'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: const Text('Flush pending offline note changes'),
            onTap: _syncNow,
          ),
          const Divider(),
          const _SectionHeader('Diagnostics'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export diagnostics log'),
            subtitle: const Text('Share a device log with support'),
            onTap: _exportLog,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text(EnvironmentConfig.environment.name),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
