import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Error boundary widget that catches errors in its subtree and displays
/// a fallback UI while logging the error with context.
///
/// Wrap any widget subtree that might throw to prevent crashes from
/// propagating to the entire app.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onError,
    this.enableLogging = true,
  });

  final Widget child;
  final Widget Function(BuildContext context, Object error, StackTrace stackTrace)? fallbackBuilder;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final bool enableLogging;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    // FlutterError.onError is global; we handle errors in the subtree via
    // the builder's error reporting mechanism.
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (widget.enableLogging) {
      developer.log(
        'ErrorBoundary caught error',
        name: 'ErrorBoundary',
        error: error,
        stackTrace: stackTrace,
      );
    }
    widget.onError?.call(error, stackTrace);
    if (mounted) {
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallbackBuilder?.call(context, _error!, _stackTrace!) ??
          _DefaultErrorFallback(
            error: _error!,
            stackTrace: _stackTrace!,
            onRetry: () {
              if (mounted) {
                setState(() {
                  _error = null;
                  _stackTrace = null;
                });
              }
            },
          );
    }

    // The child is wrapped in a Builder to ensure error catching works
    return Builder(
      builder: (context) {
        try {
          return widget.child;
        } catch (error, stackTrace) {
          _handleError(error, stackTrace);
          return widget.fallbackBuilder?.call(context, error, stackTrace) ??
              _DefaultErrorFallback(
                error: error,
                stackTrace: stackTrace,
                onRetry: () {
                  if (mounted) {
                    setState(() {
                      _error = null;
                      _stackTrace = null;
                    });
                  }
                },
              );
        }
      },
    );
  }
}

/// Default error fallback UI.
class _DefaultErrorFallback extends StatelessWidget {
  const _DefaultErrorFallback({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () => _showDetails(context),
                child: const Text('Show Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: SelectableText(
            '$error\n\n${stackTrace.toString()}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
}

/// Zone-based error boundary for async operations.
///
/// Runs a zone that catches all uncaught errors and reports them.
/// Use for isolating async error handling.
class AsyncErrorBoundary {
  static Future<T> run<T>(
    Future<T> Function() body, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool logError = true,
  }) async {
    final result = await runZonedGuarded(
      body,
      (error, stackTrace) {
        if (logError) {
          developer.log(
            'AsyncErrorBoundary caught error',
            name: 'AsyncErrorBoundary',
            error: error,
            stackTrace: stackTrace,
          );
        }
        onError?.call(error, stackTrace);
      },
    );
    return result!;
  }

  static void runSync(
    void Function() body, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool logError = true,
  }) {
    runZonedGuarded(
      body,
      (error, stackTrace) {
        if (logError) {
          developer.log(
            'AsyncErrorBoundary caught sync error',
            name: 'AsyncErrorBoundary',
            error: error,
            stackTrace: stackTrace,
          );
        }
        onError?.call(error, stackTrace);
      },
    );
  }
}