import 'package:flutter/material.dart';

/// Shows consistent, themed snackbars throughout the app.
///
/// Usage:
///   AppSnackBar.show(context, 'Song liked!');
///   AppSnackBar.error(context, 'Could not play file.');
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: action,
        ),
      );
  }

  static void error(BuildContext context, String message) {
    show(context, message, duration: const Duration(seconds: 3));
  }

  static void success(BuildContext context, String message) {
    show(context, message);
  }
}
