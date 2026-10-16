import 'package:flutter/material.dart';

extension ShowMessage on ScaffoldMessengerState {
  /// Replaces any snackbar still showing with [text].
  void showMessage(String text) => this
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Cancel / [yesLabel] dialog. True only if the user pressed [yesLabel]
/// (tapping outside the dialog counts as Cancel).
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String yesLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yesLabel),
          ),
        ],
      ),
    ) ??
    false;
