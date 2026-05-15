import 'package:flutter/material.dart';

/// every color in the app comes from this file — no hardcoded hex elsewhere.
class AppColors {
  AppColors._();

  // primary palette
  static const Color darkBerry   = Color(0xFF7D0531); // Primary buttons, active states, headers, selected tab
  static const Color roseQuartz  = Color(0xFFB05276); // Secondary buttons, gradients, hover, loading
  static const Color blush       = Color(0xFFDBBABF); // Backgrounds, card backgrounds, empty states
  static const Color sage        = Color(0xFF75824D); // AI features accent, success, CTA
  static const Color stone       = Color(0xFFC1BEB9); // Secondary text, borders, disabled, icons

  // derived shades (computed from the primary palette)
  static const Color darkBerryDark   = Color(0xFF5A0223); // Pressed/active state of darkBerry
  static const Color darkBerryLight  = Color(0xFF9E1247); // Lighter hover of darkBerry
  static const Color roseQuartzLight = Color(0xFFCC8AAA); // Lighter rose for gradients
  static const Color blushDark       = Color(0xFFC49EA4); // Darker blush for dividers
  static const Color sageDark        = Color(0xFF566038); // Darker sage for pressed states
  static const Color sageLight       = Color(0xFF96A465); // Lighter sage for backgrounds
  static const Color stoneDark       = Color(0xFF8E8B86); // Darker stone for secondary text
  static const Color stoneLight      = Color(0xFFE8E5E0); // Near-white, subtle backgrounds

  // semantic aliases
  static const Color primary         = darkBerry;
  static const Color secondary       = roseQuartz;
  static const Color background      = blush;
  static const Color aiAccent        = sage;
  static const Color textSecondary   = stone;

  // surface colors
  static const Color surfaceLight    = Color(0xFFF5EEEF); // Card surface in light mode
  static const Color surfaceDark     = Color(0xFF1A0A0F); // Card surface in dark mode
  static const Color backgroundDark  = Color(0xFF120709); // Page background in dark mode

  // glassmorphic mini-player
  static const Color glassBackground = Color(0x33DBBABF); // Blush at ~20% opacity
  static const Color glassBorder     = Color(0x33FFFFFF); // White at ~20% opacity
  static const Color glassDark       = Color(0x557D0531); // Dark berry glass for dark mode

  //  participant pastel palette for room avatars
  static const List<Color> participantColors = [
    Color(0xFFFFB3BA), // Pastel pink
    Color(0xFFFFDFBA), // Pastel peach
    Color(0xFFFFFFBA), // Pastel yellow
    Color(0xFFBAFFBA), // Pastel green
    Color(0xFFBAE1FF), // Pastel blue
    Color(0xFFE8BAFF), // Pastel lavender
    Color(0xFFFFBAE8), // Pastel rose
    Color(0xFFBAFFF0), // Pastel mint
  ];

  // utility
  static const Color error   = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF57C00);
  static const Color info    = Color(0xFF0288D1);
  static const Color white   = Color(0xFFFFFFFF);
  static const Color black   = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
}
