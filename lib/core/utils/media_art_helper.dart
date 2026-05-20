import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/library/models/song_model.dart';

/// Resolves a local or remote URI for lock-screen / notification artwork.
class MediaArtHelper {
  MediaArtHelper._();

  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static final Map<String, Uri?> _uriCache = {};

  static Future<Uri?> uriForSong(SongItem song) async {
    final cacheKey = song.persistId;
    if (_uriCache.containsKey(cacheKey)) {
      return _uriCache[cacheKey];
    }

    Uri? uri;

    if (song.albumArtUrl != null && song.albumArtUrl!.isNotEmpty) {
      uri = Uri.tryParse(song.albumArtUrl!);
    }

    if (uri == null) {
      try {
        final bytes = await _audioQuery.queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 512,
        );
        if (bytes != null && bytes.isNotEmpty) {
          uri = await _writeTempArt(song.id, bytes);
        }
      } catch (e) {
        debugPrint('[MediaArtHelper] device art failed: $e');
      }
    }

    if (uri == null &&
        song.albumArtUrl != null &&
        song.albumArtUrl!.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(song.albumArtUrl!))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          uri = await _writeTempArt(song.id, res.bodyBytes);
        }
      } catch (e) {
        debugPrint('[MediaArtHelper] download art failed: $e');
      }
    }

    _uriCache[cacheKey] = uri;
    return uri;
  }

  static Future<Uri> _writeTempArt(int songId, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vynl_art_$songId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.uri;
  }
}
