import 'dart:async';
import 'dart:math';

/// Generates a short, scannable hex trace id (e.g. `8F31A2`).
///
/// Used to correlate a single user action across every layer of the app
/// (UI → cubit → service → LLM adapter → native bridge). The 24 bits of
/// entropy are sufficient for debugging sessions; ids are short enough to
/// scan in a terminal log stream.
String newTraceId({int length = 6}) {
  final rand = Random.secure();
  const chars = '0123456789ABCDEF';
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// Zone variable key that stores the active trace id.
const _traceKey = #edge_llm_hub.trace_context.current;

/// Zone-scoped trace id propagation.
///
/// Wraps an operation in a [Zone] so every layer in the call stack —
/// UI, cubit, service, LLM adapter, native bridge — can read the same
/// trace id via [current] without changing method signatures. Combined
/// with [JsonLogger], emitted log lines automatically carry the id under
/// the `correlationId` key.
abstract final class TraceContext {
  /// The trace id bound to the current zone, or null outside a trace.
  static String? get current => Zone.current[_traceKey] as String?;

  /// Runs [body] with [traceId] bound to the current zone.
  ///
  /// Any future or stream created inside [body] (including awaited async
  /// work) inherits the zone, so [current] stays visible across the whole
  /// operation. Returns [body]'s result, which may be a value, void, or a
  /// future.
  static R trace<R>(String traceId, R Function() body) {
    return runZoned(body, zoneValues: {_traceKey: traceId});
  }
}
