/// All SharedPreferences keys in one place.
/// Never write a raw string key outside this file.
class PrefsKeys {
  PrefsKeys._();

  static const String likedSongs      = 'liked_songs';        // List<String> of song IDs
  static const String recentlyPlayed  = 'recently_played';    // List<String> of song IDs
  static const String themeMode       = 'theme_mode';         // 'light' | 'dark' | 'system'
  static const String micPermission   = 'mic_permission';     // bool
  static const String roomHistory     = 'room_history';       // List<String> of room codes
  static const String username        = 'username';           // String
  static const String avatarIndex     = 'avatar_index';       // int
  static const String listeningTime   = 'listening_time_ms';  // int (milliseconds)
  static const String roomsCreated    = 'rooms_created';      // int
  static const String playlists       = 'playlists';          // Persistently stored JSON string
}
