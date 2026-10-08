import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/error_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initCrashlytics();
  runApp(const YameApp());
}

Future<void> _initCrashlytics() async {
  if (kDebugMode || kIsWeb) return;
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    ErrorReporter.crashlyticsEnabled = true;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Observability must never prevent the app from starting.
  }
}
