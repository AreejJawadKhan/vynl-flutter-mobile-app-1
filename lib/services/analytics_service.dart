import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Central Firebase Analytics logging for Vynl.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> setUser(String? uid) async {
    try {
      await _analytics.setUserId(id: uid);
    } catch (e) {
      debugPrint('[Analytics] setUserId error: $e');
    }
  }

  static Future<void> logLogin({required String method}) async {
    await _log('login', {'method': method});
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('[Analytics] logLogin error: $e');
    }
  }

  static Future<void> logSignUp({required String method}) async {
    await _log('sign_up', {'method': method});
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('[Analytics] logSignUp error: $e');
    }
  }

  static Future<void> logSongPlayed({
    required String title,
    required String artist,
    required String genre,
    required bool hasAlbumArt,
  }) async {
    await _log('song_played', {
      'song_title': title,
      'artist': artist,
      'genre': genre,
      'has_album_art': hasAlbumArt ? '1' : '0',
    });
  }

  static Future<void> logVoiceCommand({
    required String intent,
    required bool usedGemini,
    required bool success,
  }) async {
    await _log('voice_command', {
      'intent': intent,
      'parser': usedGemini ? 'gemini' : 'local',
      'success': success ? '1' : '0',
    });
  }

  static Future<void> logBlendCalculated({
    required int compatibilityPct,
    required bool noHistoryYet,
  }) async {
    await _log('blend_calculated', {
      'compatibility_pct': compatibilityPct.toString(),
      'no_history': noHistoryYet ? '1' : '0',
    });
  }

  static Future<void> logLibraryScan({required int songCount}) async {
    await _log('library_scan', {'song_count': songCount.toString()});
  }

  static Future<void> logEnrichmentComplete({
    required int fetched,
    required int totalSongs,
  }) async {
    await _log('library_enrichment', {
      'fetched': fetched.toString(),
      'total_songs': totalSongs.toString(),
    });
  }

  static Future<void> _log(
    String name,
    Map<String, Object> parameters,
  ) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('[Analytics] $name error: $e');
    }
  }
}
