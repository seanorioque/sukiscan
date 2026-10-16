import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDb();
  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const SukiScanApp(),
  ));
}
