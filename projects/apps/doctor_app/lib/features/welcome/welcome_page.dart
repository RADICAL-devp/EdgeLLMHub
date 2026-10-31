import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/config/model_config.dart';
import '../../core/services/model_manager_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/ui/app_routes.dart';
import '../../core/ui/privacy_dialog.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _consent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = GetIt.I<SettingsService>();
    _consent = settings.hasAcceptedConsent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (settings.hasCompletedOnboarding) {
        context.go(AppRoutes.dashboard);
      }
    });
  }

  Future<void> _continue() async {
    if (!_consent || _busy) return;
    setState(() => _busy = true);
    final settings = GetIt.I<SettingsService>();
    await settings.completeOnboarding();

    var modelsReady = false;
    try {
      modelsReady = (await GetIt.I<ModelManagerService>().getStatus()).allReady;
    } catch (_) {
      modelsReady = false;
    }

    if (!mounted) return;
    context.go(modelsReady ? AppRoutes.dashboard : AppRoutes.setup);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.medical_information_outlined,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Private, on-device clinical documentation',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No account. No sign-in. This device only.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PrivacyRow(
                            icon: Icons.phonelink_lock_outlined,
                            title: 'Stays on this device',
                            body:
                                'Audio and transcripts are processed locally. '
                                'Nothing is uploaded.',
                          ),
                          SizedBox(height: 14),
                          _PrivacyRow(
                            icon: Icons.delete_outline,
                            title: 'Audio is temporary',
                            body:
                                'The recording is deleted immediately after '
                                'on-device transcription.',
                          ),
                          SizedBox(height: 14),
                          _PrivacyRow(
                            icon: Icons.lock_outline,
                            title: 'Encrypted notes',
                            body:
                                'Saved notes are encrypted with a key in the '
                                'platform secure store.',
                          ),
                          SizedBox(height: 14),
                          _PrivacyRow(
                            icon: Icons.cloud_off_outlined,
                            title: 'Works offline',
                            body:
                                'After a one-time model download, the app '
                                'needs no network.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppConfig.aiDraftDisclaimer,
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (value) =>
                        setState(() => _consent = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I understand that AI-generated notes are drafts and must '
                      'be reviewed by a qualified clinician.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _consent && !_busy ? _continue : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => showPrivacyDetails(context),
                    child: const Text('Read privacy details'),
                  ),
                  Text(
                    'Model download is about ${ModelCatalog.totalSizeLabel} and '
                    'happens once. The app does not create an account.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
