import 'package:intl/intl.dart';

final _pesos = NumberFormat.decimalPattern('en_US');
final _input = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// Parses user input like "12.5" or "1,234.50" into centavos (1250 / 123450).
/// Returns null for anything else (empty, negative, 3+ decimals, letters).
int? parseCents(String input) {
  final m = _input.firstMatch(input.trim().replaceAll(',', ''));
  if (m == null) return null;
  final pesos = int.parse(m[1]!);
  final centavos = int.parse((m[2] ?? '').padRight(2, '0'));
  return pesos * 100 + centavos;
}

/// Centavos as editable text ("12.50"): no symbol, no separators; round-trips via [parseCents].
String centsToInput(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// Formats centavos as "₱1,234.50".
String formatCents(int cents) {
  final abs = cents.abs();
  final sign = cents < 0 ? '-' : '';
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$sign₱${_pesos.format(abs ~/ 100)}.$frac';
}
