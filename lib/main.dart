import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Database db;
  try {
    db = await openAppDb();
  } catch (_) {
    // Without the database nothing works: say so instead of a blank screen.
    runApp(const StartupErrorApp(onRetry: main));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SukiScanApp(),
    ),
  );
}
