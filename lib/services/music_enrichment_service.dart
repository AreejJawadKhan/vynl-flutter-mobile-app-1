import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/env.dart';

class TrackInfo {
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final String? genre;
  final int? durationMs;

  const TrackInfo({
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    this.genre,
    this.durationMs,
  });
}

class MusicEnrichmentService {
  static final MusicEnrichmentService _instance =
  MusicEnrichmentService._internal();
  factory MusicEnrichmentService() => _instance;
  MusicEnrichmentService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://ws.audioscrobbler.com/2.0/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final Map<String, TrackInfo?> _cache = {};

  Future<TrackInfo?> getTrackInfo(String artist, String title) async {
    final cacheKey = '$artist::$title';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final response = await _dio.get('', queryParameters: {
        'method': 'track.getInfo',
        'api_key': Env.lastfmKey,
        'artist': artist,
        'track': title,
        'format': 'json',
        'autocorrect': 1,
      });

      final data = response.data;
      if (data['track'] == null) {
        _cache[cacheKey] = null;
        return null;
      }

      final track = data['track'];
      final images = track['album']?['image'] as List?;

      String? artUrl;
      if (images != null && images.isNotEmpty) {
        for (final img in images.reversed) {
          final url = img['#text'] as String? ?? '';
          if (url.isNotEmpty) { artUrl = url; break; }
        }
      }

      String? genre;
      final tags = track['toptags']?['tag'] as List?;
      if (tags != null && tags.isNotEmpty) {
        genre = _normalizeGenre(tags.first['name'] as String? ?? '');
      }

      final info = TrackInfo(
        title:       track['name'] ?? title,
        artist:      track['artist']?['name'] ?? artist,
        album:       track['album']?['title'] ?? '',
        albumArtUrl: artUrl,
        genre:       genre,
        durationMs:
        int.tryParse(track['duration']?.toString() ?? ''),
      );

      _cache[cacheKey] = info;
      return info;
    } catch (e) {
      debugPrint('[MusicEnrichment] Error for $artist - $title: $e');
      _cache[cacheKey] = null;
      return null;
    }
  }

  Future<List<TrackInfo>> searchByGenre(
      String genre, {int limit = 20}) async {
    try {
      final response = await _dio.get('', queryParameters: {
        'method': 'tag.gettoptracks',
        'api_key': Env.lastfmKey,
        'tag': genre.toLowerCase(),
        'format': 'json',
        'limit': limit,
      });

      final tracks =
          response.data['tracks']?['track'] as List? ?? [];
      return tracks
          .map((t) => TrackInfo(
        title:       t['name'] ?? '',
        artist:      t['artist']?['name'] ?? '',
        album:       '',
        albumArtUrl: _extractImage(t['image'] as List?),
      ))
          .toList();
    } catch (e) {
      debugPrint('[MusicEnrichment] Genre search error: $e');
      return [];
    }
  }

  String? _extractImage(List? images) {
    if (images == null || images.isEmpty) return null;
    for (final img in images.reversed) {
      final url = img['#text'] as String? ?? '';
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  String _normalizeGenre(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('hip hop') || lower.contains('rap')) return 'Hip Hop';
    if (lower.contains('rock'))      return 'Rock';
    if (lower.contains('pop'))       return 'Pop';
    if (lower.contains('jazz'))      return 'Jazz';
    if (lower.contains('class'))     return 'Classical';
    if (lower.contains('lofi') || lower.contains('lo-fi')) return 'Lofi';
    if (lower.contains('r&b') || lower.contains('soul'))   return 'R&B';
    if (lower.contains('electronic') || lower.contains('edm')) return 'Electronic';
    if (lower.contains('country'))   return 'Country';
    if (lower.contains('metal'))     return 'Metal';
    return raw.isEmpty ? 'Other'
        : raw[0].toUpperCase() + raw.substring(1);
  }
}