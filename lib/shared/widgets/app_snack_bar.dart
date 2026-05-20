import 'package:flutter/material.dart';

class AppSnackBar {
  AppSnackBar._();

  static void show(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 2),
        SnackBarAction? action,
      }) {
    // Guard: don't show if context is not mounted or not in a valid scaffold
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: action,
          // Prevent off-screen rendering
          behavior: SnackBarBehavior.fixed,
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