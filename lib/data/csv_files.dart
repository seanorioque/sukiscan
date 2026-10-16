import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phone's file system, as far as CSV import/export needs it. A seam so
/// tests don't open real system dialogs.
abstract class CsvFiles {
  /// Lets the user choose a file and returns its bytes; null if they cancel.
  Future<Uint8List?> pick();

  /// Lets the user choose where to save; false if they cancel.
  Future<bool> save(String fileName, Uint8List bytes);
}

class DeviceCsvFiles implements CsvFiles {
  const DeviceCsvFiles();

  // Any file type is allowed: some Android file managers label .csv files with
  // a type the picker's "csv" filter would hide. A wrong file fails the parse
  // with a clear cause instead.
  @override
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a CSV file');
    return file?.readAsBytes();
  }

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save items as CSV',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
    );
    return saved != null;
  }
}

final csvFilesProvider = Provider<CsvFiles>((_) => const DeviceCsvFiles());
