import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the current time as epoch milliseconds (the `updated_at` / `created_at` unit).
typedef Clock = int Function();

/// Override in tests: `clockProvider.overrideWithValue(() => 1000)`.
final clockProvider = Provider<Clock>(
  (_) => () => DateTime.now().millisecondsSinceEpoch,
);
