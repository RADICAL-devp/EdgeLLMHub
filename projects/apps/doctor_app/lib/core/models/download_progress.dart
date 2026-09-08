class DownloadProgress {
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final String status;
  final String? errorMessage;

  const DownloadProgress({
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.status,
    this.errorMessage,
  });
}
