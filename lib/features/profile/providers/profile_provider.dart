import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';

/// Manages the user's editable profile data:
///   - Username (editable, persisted)
///   - Avatar color index (0–7, maps to AppColors.participantColors)
///
/// Stats (liked songs, listening time, rooms created) are read directly
/// from LibraryProvider and AudioProvider in the UI — no duplication here.
class ProfileProvider extends ChangeNotifier {
  String _username    = 'Music Fan';
  int    _avatarIndex = 0;

  String get username    => _username;
  int    get avatarIndex => _avatarIndex;

  ProfileProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs     = await SharedPreferences.getInstance();
    _username    = prefs.getString(PrefsKeys.username)    ?? 'Music Fan';
    _avatarIndex = prefs.getInt(PrefsKeys.avatarIndex)    ?? 0;
    notifyListeners();
  }

  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _username) return;
    _username = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.username, _username);
  }

  Future<void> setAvatarIndex(int index) async {
    if (index == _avatarIndex) return;
    _avatarIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.avatarIndex, _avatarIndex);
  }

}
