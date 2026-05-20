import 'package:flutter/foundation.dart';
import 'music_enrichment_service.dart';

/// Fetches and caches album art URLs from Last.fm.
class AlbumArtCache {
  static final AlbumArtCache _instance = AlbumArtCache._internal();
  factory AlbumArtCache() => _instance;
  AlbumArtCache._internal();

  final MusicEnrichmentService _enrichment = MusicEnrichmentService();
  final Map<String, String?> _urlCache = {};

  Future<String?> getArtUrl(String artist, String title) async {
    final key = '$artist::$title';
    if (_urlCache.containsKey(key)) return _urlCache[key];

    try {
      final info = await _enrichment.getTrackInfo(artist, title);
      _urlCache[key] = info?.albumArtUrl;
      return info?.albumArtUrl;
    } catch (e) {
      debugPrint('[AlbumArtCache] Error: $e');
      _urlCache[key] = null;
      return null;
    }
  }

  Future<String?> getGenre(String artist, String title) async {
    try {
      final info = await _enrichment.getTrackInfo(artist, title);
      return info?.genre;
    } catch (e) {
      return null;
    }
  }
}