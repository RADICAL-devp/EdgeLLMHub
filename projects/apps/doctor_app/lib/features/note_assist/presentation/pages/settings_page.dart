import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'package:doctor_app/features/note_assist/domain/services/diagnostics_exporter.dart';

/// Keys persisted via [SharedPreferences].
const String prefCloudLlmEnabled = 'cloud_llm_enabled';
const String prefPhiConsentGranted = 'phi_consent_granted';

/// App settings: privacy toggles (cloud processing / PHI consent), device
/// capability info, and sync-queue diagnostics with log export.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SharedPreferences _prefs;
  bool _loaded = false;
  bool _cloudLlmEnabled = false;
  bool _phiConsentGranted = false;
  ExecutionMode _recommendedMode = ExecutionMode.cloud;
  final List<String> _consentAuditTrail = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final capability = GetIt.I<DeviceCapabilityService>();
    final recommended = await capability.getRecommendedExecutionMode();

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _cloudLlmEnabled = prefs.getBool(prefCloudLlmEnabled) ??
          EnvironmentConfig.cloudLlmEnabled;
      _phiConsentGranted =
          prefs.getBool(prefPhiConsentGranted) ?? false;
      _recommendedMode = recommended;
      _loaded = true;
    });
  }

  Future<void> _setCloudLlm(bool value) async {
    // Cloud processing is only permitted with explicit PHI consent.
    // The consent toggle is the gate: enabling cloud without consent asks
    // for it inline and grants it on confirmation.
    if (value && !_phiConsentGranted) {
      final granted = await _requestConsentDialog();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cloud processing NOT enabled — PHI consent required.'),
        ));
        return;
      }
      // Consent granted as part of enabling cloud processing.
      setState(() => _phiConsentGranted = true);
      await _prefs.setBool(prefPhiConsentGranted, true);
      _recordConsentChange(true);
    }

    setState(() => _cloudLlmEnabled = value);
    await _prefs.setBool(prefCloudLlmEnabled, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value
          ? 'Cloud processing enabled. PHI may leave the device.'
          : 'On-device processing only. PHI stays on the device.'),
    ));
  }

  /// Confirmation dialog that captures explicit PHI consent before cloud
  /// processing can be enabled. Returns true when the user explicitly.
  Future<bool> _requestConsentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PHI consent required'),
        content: const Text(
          'Enabling cloud processing means protected health information '
          '(PHI) may be transmitted to the processing service. You must '
          'explicitly consent before any cloud request is made.\n\n'
          'Do you consent to cloud processing of PHI?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I Consent'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _setPhiConsent(bool value) async {
    final consentChanged = value != _phiConsentGranted;
    setState(() {
      _phiConsentGranted = value;
      // Revoking consent disables cloud processing too — PHI may not leave
      // the device without explicit consent.
      if (!value) _cloudLlmEnabled = false;
    });
    await _prefs.setBool(prefPhiConsentGranted, value);
    await _prefs.setBool(prefCloudLlmEnabled, _cloudLlmEnabled);
    if (consentChanged) _recordConsentChange(value);
  }

  /// Append a timestamped consent status change to the in-memory audit
  /// trail that is emitted with the diagnostics export payload.
  void _recordConsentChange(bool granted) {
    final now = DateTime.now().toUtc().toIso8601String();
    _consentAuditTrail.add('consent-changed: {granted: $granted} at $now');
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
      ..writeln('Cloud LLM enabled (pref): $_cloudLlmEnabled')
      ..writeln('PHI consent granted: $_phiConsentGranted')
      ..writeln('Recommended execution mode: ${_recommendedMode.name}')
      ..writeln('Is simulator: $simulator')
      ..writeln('Supported model: ${EnvironmentConfig.supportedModels.join(', ')}')
      ..writeln()
      ..writeln('Pending sync entries: ${pending.length}');

    if (_consentAuditTrail.isNotEmpty) {
      buffer.writeln('Consent audit trail:');
      for (final entry in _consentAuditTrail) {
        buffer.writeln('  $entry');
      }
    }

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
          SwitchListTile(
            title: const Text('Allow cloud processing'),
            subtitle: Text(
              _cloudLlmEnabled
                  ? 'Enabled: PHI may be sent to the Ollama cloud service.'
                  : _phiConsentGranted
                      ? 'Disabled: all processing stays on-device where available.'
                      : 'Requires explicit PHI consent to enable.',
            ),
            value: _cloudLlmEnabled,
            onChanged: _setCloudLlm,
          ),
          SwitchListTile(
            title: const Text('PHI consent granted'),
            subtitle: const Text(
              'Consent to process protected health information. '
              'Required before any cloud request is made.',
            ),
            value: _phiConsentGranted,
            onChanged: _setPhiConsent,
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