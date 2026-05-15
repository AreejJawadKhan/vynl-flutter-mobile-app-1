import 'dart:math';

/// Utility functions used across the app.
class AppUtils {
  AppUtils._();

  static final Random _rng = Random();

  /// Formats a [Duration] to m:ss (e.g. 3:07, 12:45).
  /// Used for song duration display and playback timestamps.
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats milliseconds to m:ss.
  static String formatMs(int ms) => formatDuration(Duration(milliseconds: ms));

  /// Generates a random 6-character alphanumeric room code.
  /// Characters chosen to be unambiguous (no O/0, I/1/l).
  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  /// Truncates a string to [maxLength] with an ellipsis.
  static String truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength - 1)}…';
  }

  /// Returns a pastel participant color by index (wraps around).
  static int participantColorIndex(int participantCount) {
    return participantCount % 8; // 8 pastel colors defined in AppColors
  }
}
