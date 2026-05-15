import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralised permission handling.
/// Call these before any feature that needs a sensitive permission.
class PermissionHelper {
  PermissionHelper._();

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Requests the appropriate storage permission for the running Android version.
  /// Returns true if granted.
  static Future<bool> requestStorage() async {
    // Android 13+ uses READ_MEDIA_AUDIO instead of READ_EXTERNAL_STORAGE.
    final status = await Permission.audio.request();
    if (status.isGranted) return true;

    // Fallback for older devices.
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  static Future<bool> hasStorage() async {
    final audio = await Permission.audio.status;
    if (audio.isGranted) return true;
    return (await Permission.storage.status).isGranted;
  }

  // ── Microphone ────────────────────────────────────────────────────────────

  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> hasMicrophone() async {
    return (await Permission.microphone.status).isGranted;
  }

  // ── Denied permanently — open settings ────────────────────────────────────

  /// Opens the app's system settings page when a permission is permanently denied.
  static Future<void> openSettings() => openAppSettings();

  // ── Permission dialog helper ───────────────────────────────────────────────

  /// Shows a rationale dialog then requests [permission].
  /// Returns true if the user ultimately grants it.
  static Future<bool> requestWithRationale({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String rationale,
  }) async {
    final status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      // Show settings prompt.
      if (!context.mounted) return false;
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(
            '$rationale\n\nPlease enable it in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (goToSettings == true) await openAppSettings();
      return false;
    }

    // Show rationale then request.
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(rationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    final result = await permission.request();
    return result.isGranted;
  }
}
