/// Telemetry service for logging AI assistance interactions.
///
/// Logs events like suggestion acceptance, rejection, editing for
/// analytics and model improvement.
class TelemetryService {
  TelemetryService._();
  static final TelemetryService _instance = TelemetryService._();
  factory TelemetryService() => _instance;

  /// Event buffer for batch sending.
  final List<Map<String, dynamic>> _eventBuffer = [];
  static const int _bufferSize = 50;

  /// Log an event to the buffer.
  void logEvent(String eventType, Map<String, dynamic> data) {
    _eventBuffer.add({
      'type': eventType,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Flush if buffer full
    if (_eventBuffer.length >= _bufferSize) {
      flush();
    }
  }

  /// Flush events to backend (or local storage).
  Future<void> flush() async {
    if (_eventBuffer.isEmpty) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_eventBuffer);
    _eventBuffer.clear();

    try {
      // TODO: Send to backend analytics endpoint
      // Example: POST /api/v1/telemetry/batch
      // For now, just log locally
      for (final event in eventsToSend) {
        // ignore: avoid_print
        print('[Telemetry] ${event['type']}: ${event['data']}');
      }
    } catch (e) {
      // Re-add to buffer on failure
      _eventBuffer.insertAll(0, eventsToSend);
    }
  }

  /// Get count of buffered events.
  int get bufferedCount => _eventBuffer.length;
}