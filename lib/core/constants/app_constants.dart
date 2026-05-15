/// All magic numbers live here. Never hardcode dimensions or durations elsewhere.
class AppConstants {
  AppConstants._();

  // ── Mini-player ───────────────────────────────────────────────────────────
  static const double miniPlayerCollapsedHeight = 70.0;
  static const double miniPlayerExpandedHeight  = 200.0;
  static const double miniPlayerBorderRadius    = 20.0;
  static const double miniPlayerBlurSigma       = 20.0;
  static const Duration miniPlayerAnimDuration  = Duration(milliseconds: 300);

  // ── Vinyl animation ───────────────────────────────────────────────────────
  static const double vinylDiameter       = 280.0;
  static const double vinylLabelDiameter  = 200.0;
  static const double vinylRpm            = 33.333; // 33⅓ RPM
  // Full rotation (2π radians) in milliseconds at 33⅓ RPM
  static final int vinylRotationMs        = (60000 / vinylRpm).round(); // ~1800ms per rotation

  // ── Library ───────────────────────────────────────────────────────────────
  static const double albumArtListSize     = 50.0;
  static const double albumArtMiniSmall    = 40.0;
  static const double albumArtMiniLarge    = 60.0;
  static const int    recentlyPlayedMax    = 20;
  static const int    playlistMax          = 10;

  // ── Rooms ─────────────────────────────────────────────────────────────────
  static const int    roomCodeLength       = 6;
  static const int    roomMaxParticipants  = 20;
  static const int    roomHistoryMax       = 3;
  static const double skipVoteThreshold   = 0.50; // 50%
  static const double replayVoteThreshold = 0.60; // 60%
  static const Duration roomIdleTimeout   = Duration(minutes: 5);

  // ── Voice search ─────────────────────────────────────────────────────────
  static const Duration voiceListenDuration = Duration(seconds: 10);
  static const int    commandHistoryMax      = 3;

  // ── Spacing grid (8px base) ───────────────────────────────────────────────
  static const double spaceXS  = 4.0;
  static const double spaceS   = 8.0;
  static const double spaceM   = 16.0;
  static const double spaceL   = 24.0;
  static const double spaceXL  = 32.0;
  static const double spaceXXL = 48.0;

  // ── Border radii ──────────────────────────────────────────────────────────
  static const double radiusS   = 8.0;
  static const double radiusM   = 12.0;
  static const double radiusL   = 16.0;
  static const double radiusXL  = 24.0;
  static const double radiusFull = 100.0;

  // ── Icon sizes ────────────────────────────────────────────────────────────
  static const double iconS  = 18.0;
  static const double iconM  = 24.0;
  static const double iconL  = 32.0;
  static const double iconXL = 48.0;

  // ── Bottom nav ────────────────────────────────────────────────────────────
  static const double bottomNavHeight = 64.0;
}
