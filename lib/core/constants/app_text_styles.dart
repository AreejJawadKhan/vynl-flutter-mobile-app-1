import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// All text styles used across the app.
/// Uses GoogleFonts.poppins() so no manual font asset registration is needed.
/// Reference via AppTextStyles.headlineLarge etc.
class AppTextStyles {
  AppTextStyles._();

  // ── Display / Hero text ───────────────────────────────────────────────────
  static TextStyle get display => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.darkBerry,
      );

  // ── Headlines ─────────────────────────────────────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.darkBerry,
      );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.darkBerry,
      );

  static TextStyle get headlineSmall => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBerry,
      );

  // ── Body text ─────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.darkBerry,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.stoneDark,
      );

  static TextStyle get bodySmall => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.stone,
      );

  // ── Song tile ─────────────────────────────────────────────────────────────
  static TextStyle get songTitle => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBerry,
      );

  static TextStyle get songArtist => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.stoneDark,
      );

  static TextStyle get songDuration => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.stone,
      );

  // ── Now Playing ───────────────────────────────────────────────────────────
  static TextStyle get nowPlayingTitle => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.darkBerry,
      );

  static TextStyle get nowPlayingArtist => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.roseQuartz,
      );

  // ── Labels / Chips ────────────────────────────────────────────────────────
  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.stoneDark,
      );

  static TextStyle get labelBold => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.darkBerry,
      );

  // ── Navigation ────────────────────────────────────────────────────────────
  static TextStyle get navLabel => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      );

  // ── Buttons ───────────────────────────────────────────────────────────────
  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.white,
      );

  // ── Room code ─────────────────────────────────────────────────────────────
  static TextStyle get roomCode => GoogleFonts.robotoMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        color: AppColors.darkBerry,
      );

  // ── Timestamp ─────────────────────────────────────────────────────────────
  static TextStyle get timestamp => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.stone,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
}
