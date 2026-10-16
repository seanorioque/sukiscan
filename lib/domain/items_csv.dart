import 'dart:convert';
import 'dart:typed_data';

import '../core/money.dart';
import 'item.dart';

// Items <-> CSV. Columns: barcode, item name, price, stock quantity.
// Pure Dart. Only "stock quantity" may be blank; anything else missing or
// invalid makes the whole import fail, and every cause is reported.

const _barcodeCol = 'barcode';
const _nameCol = 'item name';
const _priceCol = 'price';
const _stockCol = 'stock quantity';

/// One valid row of an import. [stockQty] is null when the cell was blank:
/// a new item then starts at 0 and an existing item keeps its stock.
class CsvItem {
  const CsvItem({
    required this.barcode,
    required this.name,
    required this.priceCents,
    this.stockQty,
  });

  final String barcode;
  final String name;
  final int priceCents;
  final int? stockQty;
}

/// What reading a CSV file produced. Either [items] (no [problems]) or a list
/// of human-readable causes, in which case nothing may be imported.
class CsvImport {
  const CsvImport({this.items = const [], this.problems = const []});

  final List<CsvItem> items;
  final List<String> problems;

  bool get ok => problems.isEmpty;
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// CSV text for [items] (header + one row each), UTF-8 BOM first so Excel
/// reads names like "Piña" or "₱" correctly. Prices are plain "15.00".
String itemsToCsv(List<Item> items) {
  final rows = [
    [_barcodeCol, _nameCol, _priceCol, _stockCol],
    for (final i in items)
      [i.barcode, i.name, centsToInput(i.priceCents), '${i.stockQty}'],
  ];
  return '﻿${rows.map((r) => r.map(_field).join(',')).join('\r\n')}\r\n';
}

String _field(String v) => v.contains(RegExp(r'[",\r\n]')) || v != v.trim()
    ? '"${v.replaceAll('"', '""')}"'
    : v;

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------

/// Reads a CSV file's bytes into items, or into every reason it can't be used.
CsvImport parseItemsCsv(Uint8List bytes) {
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return const CsvImport(
      problems: [
        'The file is not UTF-8 text. In Excel use Save As and choose '
            '"CSV UTF-8 (Comma delimited)".',
      ],
    );
  }

  final List<List<String>> rows;
  try {
    rows = parseCsv(text);
  } on FormatException catch (e) {
    return CsvImport(problems: [e.message]);
  }
  if (rows.isEmpty) return const CsvImport(problems: ['The file is empty.']);

  // --- header ---
  final header = [for (final c in rows.first) _norm(c)];
  final col = {for (final (i, name) in header.indexed) name: i};
  final missing = [
    for (final c in [_barcodeCol, _nameCol, _priceCol])
      if (!col.containsKey(c)) c,
  ];
  if (missing.isNotEmpty) {
    final semicolons = rows.first.length == 1 && rows.first.first.contains(';');
    return CsvImport(
      problems: [
        if (semicolons)
          'This file separates columns with semicolons. Save it as '
              'comma-separated CSV.'
        else
          'The first row must be the column names. Missing: '
              '${missing.join(', ')}. Expected: barcode, item name, price, '
              'stock quantity.',
      ],
    );
  }

  // --- data rows (row 1 is the header, as a spreadsheet would number them) ---
  final problems = <String>[];
  final items = <CsvItem>[];
  final firstRowOf = <String, int>{};
  for (var r = 1; r < rows.length; r++) {
    final cells = rows[r];
    if (cells.every((c) => c.trim().isEmpty)) continue; // blank line
    String cell(String name) {
      final i = col[name];
      return i == null || i >= cells.length ? '' : cells[i].trim();
    }

    final rowNo = r + 1;
    final causes = <String>[];

    final barcode = cell(_barcodeCol);
    if (barcode.isEmpty) {
      causes.add('barcode is empty');
    } else if (RegExp(r'^\d+(\.\d+)?[eE][+-]?\d+$').hasMatch(barcode)) {
      causes.add(
        'barcode "$barcode" looks like Excel scientific notation; format the '
        'barcode column as Text and export again',
      );
    } else if (firstRowOf[barcode] case final first?) {
      causes.add('barcode "$barcode" is already used on row $first');
    }

    final name = cell(_nameCol);
    if (name.isEmpty) causes.add('item name is empty');

    final price = _price(cell(_priceCol));
    if (price.error != null) causes.add(price.error!);

    final stockText = cell(_stockCol);
    int? stock;
    if (stockText.isNotEmpty) {
      stock = int.tryParse(stockText);
      if (stock == null) {
        causes.add('stock quantity "$stockText" is not a whole number');
      }
    }

    if (causes.isNotEmpty) {
      problems.add('Row $rowNo: ${causes.join('; ')}.');
      continue;
    }
    firstRowOf[barcode] = rowNo;
    items.add(
      CsvItem(
        barcode: barcode,
        name: name,
        priceCents: price.cents!,
        stockQty: stock,
      ),
    );
  }

  if (problems.isNotEmpty) return CsvImport(problems: problems);
  if (items.isEmpty) {
    return const CsvImport(
      problems: ['The file has no items, only the column names.'],
    );
  }
  return CsvImport(items: items);
}

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

({int? cents, String? error}) _price(String raw) {
  if (raw.isEmpty) return (cents: null, error: 'price is empty');
  final text = raw.replaceFirst('₱', '').trim();
  // A comma is only accepted as a thousands separator ("1,234.50"): "12,50"
  // would otherwise be read as 1250 pesos.
  final grouped = RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$');
  final bad = (
    cents: null,
    error: 'price "$raw" is not a valid amount (use a number like 12.50)',
  );
  if (text.contains(',') && !grouped.hasMatch(text)) return bad;
  final cents = parseCents(text);
  if (cents == null) return bad;
  if (cents == 0) return (cents: null, error: 'price must be greater than 0');
  return (cents: cents, error: null);
}

/// Splits CSV text into rows of cells (RFC 4180: quoted cells may contain
/// commas, line breaks and doubled quotes). Throws [FormatException] if a
/// quote is never closed.
List<List<String>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var cellStarted =
      false; // true once the current cell has any content or quote

  void endCell() {
    row.add(cell.toString());
    cell.clear();
    cellStarted = false;
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"'); // "" is a literal quote
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && !cellStarted) {
      inQuotes = true;
      cellStarted = true;
    } else if (ch == ',') {
      endCell();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(ch);
      cellStarted = true;
    }
  }
  if (inQuotes) {
    throw FormatException(
      'A quoted value is never closed (row ${rows.length + 1}). '
      'Check for a missing closing quote.',
    );
  }
  // The last row, if the text doesn't end with a line break.
  if (cellStarted || cell.isNotEmpty || row.isNotEmpty) {
    endRow();
  }
  return rows;
}
