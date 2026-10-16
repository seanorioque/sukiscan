import 'dart:convert';
import 'dart:typed_data';

import 'package:sukiscan/data/csv_files.dart';

/// Stands in for the system file picker / save dialog.
class FakeCsvFiles implements CsvFiles {
  /// What "the user picked": null means they cancelled.
  Uint8List? toPick;

  bool failPick = false;
  bool failSave = false;

  /// False = the user cancelled the save dialog.
  bool saveAccepted = true;

  /// Everything saved: file name, the raw bytes, and the text (Dart's decoder
  /// drops a leading UTF-8 BOM, so check [bytes] to see the BOM).
  final saved = <({String name, Uint8List bytes, String text})>[];

  /// Sets the picked file from CSV text.
  void pickText(String text) => toPick = Uint8List.fromList(utf8.encode(text));

  @override
  Future<Uint8List?> pick() async {
    if (failPick) throw StateError('no access');
    return toPick;
  }

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (failSave) throw StateError('disk full');
    saved.add((name: fileName, bytes: bytes, text: utf8.decode(bytes)));
    return saveAccepted;
  }
}
