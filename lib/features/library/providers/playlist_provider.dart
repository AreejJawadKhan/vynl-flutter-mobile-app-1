import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/prefs_keys.dart';
import '../models/song_model.dart';
import 'library_provider.dart';

class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: List<String>.from(json['songIds'] as List<dynamic>),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Playlist copyWith({String? name, List<String>? songIds}) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
    );
  }
}

class PlaylistProvider extends ChangeNotifier {
  final List<Playlist> _playlists = [];
  LibraryProvider? _library;

  bool _loading = false;
  String? _error;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isLoading => _loading;
  String? get error => _error;

  void updateLibrary(LibraryProvider library) {
    _library = library;
    // We don't automatically load here because main.dart handles initialization.
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(PrefsKeys.playlists);
      if (raw == null || raw.trim().isEmpty) {
        _playlists.clear();
      } else {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _playlists..clear()..addAll(decoded.map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map))).toList());
      }
    } catch (e) {
      _error = 'Failed to load playlists';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (_playlists.length >= AppConstants.playlistMax) {
      _error = 'You can create up to ${AppConstants.playlistMax} playlists.';
      notifyListeners();
      return false;
    }
    _playlists.add(Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      songIds: const [],
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _save();
  }

  Future<void> addSong(String playlistId, SongItem song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final target = _playlists[idx];
    if (target.songIds.contains(song.persistId)) return;
    _playlists[idx] = target.copyWith(songIds: [...target.songIds, song.persistId]);
    notifyListeners();
    await _save();
  }

  Future<void> removeSong(String playlistId, String songPersistId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final target = _playlists[idx];
    final newSongIds = List<String>.from(target.songIds)..remove(songPersistId);
    _playlists[idx] = target.copyWith(songIds: newSongIds);
    notifyListeners();
    await _save();
  }

  List<SongItem> songsForPlaylist(Playlist playlist) {
    final lib = _library;
    if (lib == null) return const [];
    final map = {for (final s in lib.allSongs) s.persistId: s};
    return playlist.songIds.where(map.containsKey).map((id) => map[id]!).toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.playlists, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
  }
}
