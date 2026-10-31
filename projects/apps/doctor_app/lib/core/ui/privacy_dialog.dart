import 'package:flutter/material.dart';

/// Shared privacy copy so the welcome and settings screens cannot drift apart.
Future<void> showPrivacyDetails(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy and data handling'),
      content: const SingleChildScrollView(
        child: Text(
          'Clinical Notes AI is designed for local-only documentation.\n\n'
          '• Audio is captured as a temporary 16 kHz PCM file on this device. '
          'It is deleted immediately after transcription.\n\n'
          '• Speech recognition and note drafting run on this device using '
          'downloaded model files. No audio, transcript, or note is sent to a '
          'server.\n\n'
          '• Notes are encrypted at rest with a key held in the platform secure '
          'store (Keychain on iOS, Keystore-backed storage on Android). The '
          'note text is encrypted field by field; the database file itself '
          'does not contain readable clinical text.\n\n'
          '• The app has no account system, no cloud sync, and no analytics '
          'that include patient content.\n\n'
          '• Model files are downloaded once from the model publisher. The '
          'download request contains no patient data. Model files are not '
          'patient data and are stored unencrypted.\n\n'
          '• AI output is a draft. A qualified clinician must review every '
          'section before using the note for care.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
