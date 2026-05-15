import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/prefs_keys.dart';
import '../../core/utils/permission_helper.dart';
import '../../shared/providers/audio_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../features/library/screens/liked_songs_screen.dart';
import '../../features/library/providers/library_provider.dart';
import 'providers/profile_provider.dart';

/// Profile screen — tab 4 in the bottom navigation.
///
/// Shows:
///   - Avatar circle (8 colour options from AppColors.participantColors)
///   - Editable username
///   - Stats: songs liked, total songs, listening time, rooms created
///   - Settings: dark mode toggle, microphone permission status
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final theme   = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final audio   = context.watch<AudioProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spaceM,
          AppConstants.spaceM,
          AppConstants.spaceM,
          AppConstants.miniPlayerCollapsedHeight +
              AppConstants.bottomNavHeight +
              AppConstants.spaceXL,
        ),
        children: [
          // ── Avatar + name ─────────────────────────────────────────────
          _AvatarSection(profile: profile),

          const SizedBox(height: AppConstants.spaceXL),

          // ── Stats card ────────────────────────────────────────────────
          _StatsCard(library: library, audio: audio),

          const SizedBox(height: AppConstants.spaceL),

          // ── Settings card ─────────────────────────────────────────────
          _SettingsCard(theme: theme),
        ],
      ),
    );
  }
}

// ── Avatar section ────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final ProfileProvider profile;
  const _AvatarSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.participantColors[
        profile.avatarIndex % AppColors.participantColors.length];

    return Column(
      children: [
        // ── Avatar circle with tap-to-change ────────────────────────────
        GestureDetector(
          onTap: () => _showAvatarPicker(context, profile),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width:  96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.25),
                  border: Border.all(color: color, width: 3),
                ),
                child: Center(
                  child: Text(
                    profile.username.isNotEmpty
                        ? profile.username[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.display.copyWith(
                      color: color,
                      fontSize: 40,
                    ),
                  ),
                ),
              ),
              // Edit badge
              Container(
                width:  28,
                height: 28,
                decoration: BoxDecoration(
                  color:  AppColors.darkBerry,
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2),
                ),
                child: const Icon(Icons.edit_rounded,
                    size: 14, color: AppColors.white),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.spaceL),

        // ── Editable username ───────────────────────────────────────────
        _UsernameField(profile: profile),
      ],
    );
  }

  void _showAvatarPicker(BuildContext context, ProfileProvider profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (_) => ChangeNotifierProvider<ProfileProvider>.value(
        value: profile,
        child: const _AvatarPickerSheet(),
      ),
    );
  }
}

class _UsernameField extends StatefulWidget {
  final ProfileProvider profile;
  const _UsernameField({required this.profile});

  @override
  State<_UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<_UsernameField> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.profile.username);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.profile.setUsername(_ctrl.text);
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () => setState(() => _editing = true),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.profile.username,
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.stone),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller:         _ctrl,
            autofocus:          true,
            textAlign:          TextAlign.center,
            textCapitalization: TextCapitalization.words,
            style:              AppTextStyles.headlineMedium,
            textInputAction:    TextInputAction.done,
            onSubmitted:        (_) => _save(),
            decoration: const InputDecoration(
              hintText:        'Enter your name',
              contentPadding:  EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon:      const Icon(Icons.check_rounded),
          color:     AppColors.sage,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Avatar picker sheet ───────────────────────────────────────────────────────

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stone.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceL),
            Text('Choose colour', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppConstants.spaceL),

            // 8 colour swatches in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                AppColors.participantColors.length,
                (i) {
                  final color     = AppColors.participantColors[i];
                  final isSelected = i == profile.avatarIndex;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<ProfileProvider>().setAvatarIndex(i);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width:  48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(isSelected ? 1.0 : 0.4),
                        border: Border.all(
                          color:  isSelected ? AppColors.darkBerry : Colors.transparent,
                          width:  3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.darkBerry, size: 22)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppConstants.spaceL),
          ],
        ),
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final LibraryProvider library;
  final AudioProvider   audio;
  const _StatsCard({required this.library, required this.audio});

  /// Formats milliseconds into a readable listening time string.
  /// e.g. 3,661,000 ms → "1h 1m"
  String _formatListeningTime(int ms) {
    if (ms <= 0) return '0m';
    final total   = Duration(milliseconds: ms);
    final hours   = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '< 1m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
      ),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your stats', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppConstants.spaceL),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                    );
                  },
                  child: _StatTile(
                    icon:  Icons.favorite_rounded,
                    color: AppColors.roseQuartz,
                    value: '${library.likedCount}',
                    label: 'Liked songs',
                  ),
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon:  Icons.library_music_rounded,
                  color: AppColors.darkBerry,
                  value: '${library.totalCount}',
                  label: 'In library',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon:  Icons.access_time_rounded,
                  color: AppColors.sage,
                  value: _formatListeningTime(audio.totalListeningMs),
                  label: 'Listened',
                ),
              ),
              Expanded(
                child: _AsyncStatTile(
                  icon:   Icons.people_alt_rounded,
                  color:  AppColors.roseQuartz,
                  label:  'Rooms created',
                  future: _loadRoomsCreated(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<int> _loadRoomsCreated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PrefsKeys.roomsCreated) ?? 0;
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   value;
  final String   label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color:  color.withOpacity(0.12),
            shape:  BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(fontSize: 22),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A stat tile that loads its value asynchronously from a [Future<int>].
/// Shows '…' while loading.
class _AsyncStatTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final Future<int>  future;

  const _AsyncStatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: future,
      builder: (_, snap) {
        final value = snap.hasData ? '${snap.data}' : '…';
        return _StatTile(
          icon:  icon,
          color: color,
          value: value,
          label: label,
        );
      },
    );
  }
}

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatefulWidget {
  final ThemeProvider theme;
  const _SettingsCard({required this.theme});

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  bool? _hasMic;

  @override
  void initState() {
    super.initState();
    _checkMic();
  }

  Future<void> _checkMic() async {
    final has = await PermissionHelper.hasMicrophone();
    if (mounted) setState(() => _hasMic = has);
  }

  Future<void> _requestMic() async {
    final granted = await PermissionHelper.requestMicrophone();
    if (mounted) setState(() => _hasMic = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Microphone access denied. Enable it in Settings.'),
          action: SnackBarAction(
            label:    'Settings',
            onPressed: PermissionHelper.openSettings,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.isDark;

    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
      ),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppConstants.spaceM),

          // ── Dark mode toggle ─────────────────────────────────────────
          _SettingRow(
            icon:   isDark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            label:  'Dark mode',
            subtitle: isDark ? 'On' : 'Off',
            trailing: Switch(
              value:     isDark,
              onChanged: (_) {
                HapticFeedback.selectionClick();
                widget.theme.toggle();
              },
            ),
          ),

          const Divider(height: AppConstants.spaceL),

          // ── Microphone permission ────────────────────────────────────
          _SettingRow(
            icon:    Icons.mic_rounded,
            label:   'Microphone',
            subtitle: _hasMic == null
                ? 'Checking…'
                : (_hasMic! ? 'Allowed' : 'Not allowed'),
            trailing: _hasMic == null
                ? const SizedBox(
                    width:  20,
                    height: 20,
                    child:  CircularProgressIndicator(strokeWidth: 2),
                  )
                : _hasMic!
                    ? Icon(Icons.check_circle_rounded,
                        color: AppColors.sage, size: 24)
                    : TextButton(
                        onPressed: _requestMic,
                        child: const Text('Enable'),
                      ),
          ),

          const Divider(height: AppConstants.spaceL),

          // ── App version / about ──────────────────────────────────────
          _SettingRow(
            icon:     Icons.info_outline_rounded,
            label:    'Version',
            subtitle: '1.0.0 · Phase 6',
            trailing: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Widget   trailing;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:  36,
          height: 36,
          decoration: BoxDecoration(
            color:        AppColors.blushDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
          ),
          child: Icon(icon, size: 18, color: AppColors.darkBerry),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodyLarge),
              Text(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
