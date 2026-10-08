import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Signature of the sink receiving non-fatal errors.
typedef ErrorSink = void Function(
  Object error,
  StackTrace? stack,
  String? context,
);

/// Small facade over Crashlytics. Never throws: reporting must not break flows.
class ErrorReporter {
  ErrorReporter._();

  /// Overridable in tests. When null, the default behaviour is used.
  @visibleForTesting
  static ErrorSink? sinkOverride;

  /// Set to true by main.dart once Crashlytics is initialised and enabled.
  static bool crashlyticsEnabled = false;

  static void report(Object error, StackTrace? stack, {String? context}) {
    try {
      final override = sinkOverride;
      if (override != null) {
        override(error, stack, context);
        return;
      }
      if (kDebugMode) {
        debugPrint('[ErrorReporter] ${context ?? 'unknown'}: $error');
        if (stack != null) debugPrint(stack.toString());
        return;
      }
      if (crashlyticsEnabled) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: context,
          fatal: false,
        );
      }
    } catch (_) {
      // Reporting must never throw.
    }
  }

  @visibleForTesting
  static void resetForTest() {
    sinkOverride = null;
    crashlyticsEnabled = false;
  }
}
