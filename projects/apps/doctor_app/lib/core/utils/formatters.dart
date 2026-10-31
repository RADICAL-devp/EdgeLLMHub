import 'package:intl/intl.dart';

String formatNoteTimestamp(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == today) return 'Today, ${DateFormat.jm().format(local)}';
  final yesterday = today.subtract(const Duration(days: 1));
  if (date == yesterday) return 'Yesterday, ${DateFormat.jm().format(local)}';
  if (local.year == now.year) {
    return DateFormat('MMM d, h:mm a').format(local);
  }
  return DateFormat('MMM d, yyyy').format(local);
}

String formatDay(DateTime value) => DateFormat.yMMMMd().format(value.toLocal());

String formatShortDate(DateTime value) =>
    DateFormat('MMM d').format(value.toLocal());

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  return '${mb.round()} MB';
}

int wordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return RegExp(r'\S+', unicode: true).allMatches(trimmed).length;
}

String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
