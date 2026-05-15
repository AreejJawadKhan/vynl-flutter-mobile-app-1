import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_constants.dart';

/// Light and dark ThemeData for the app.
/// AppTextStyles uses GoogleFonts so no sub-theme can be const when
/// it references a text style — those blocks use plain constructors instead.
class AppTheme {
  AppTheme._();

  // ────────────────────────────────────────────────────────────────────────────
  // Light theme
  // ────────────────────────────────────────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary:                AppColors.darkBerry,
        onPrimary:              AppColors.white,
        primaryContainer:       AppColors.blush,
        onPrimaryContainer:     AppColors.darkBerry,
        secondary:              AppColors.roseQuartz,
        onSecondary:            AppColors.white,
        secondaryContainer:     Color(0xFFEDD0D8),
        onSecondaryContainer:   AppColors.darkBerry,
        tertiary:               AppColors.sage,
        onTertiary:             AppColors.white,
        surface:                AppColors.surfaceLight,
        onSurface:              AppColors.darkBerry,
        surfaceContainerHighest: AppColors.blush,
        error:                  AppColors.error,
        onError:                AppColors.white,
        outline:                AppColors.stone,
        outlineVariant:         AppColors.blushDark,
      ),
      scaffoldBackgroundColor: AppColors.blush,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.blush,
        foregroundColor:  AppColors.darkBerry,
        elevation:        0,
        centerTitle:      true,
        titleTextStyle:   AppTextStyles.headlineSmall,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor:                   AppColors.transparent,
          statusBarIconBrightness:          Brightness.dark,
          systemNavigationBarColor:         AppColors.blush,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkBerry,
          size:  AppConstants.iconM,
        ),
      ),

      // ── Bottom navigation ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  AppColors.surfaceLight,
        indicatorColor:   AppColors.darkBerry.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.darkBerry, size: 24);
          }
          return const IconThemeData(color: AppColors.stone, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.navLabel.copyWith(
                color: AppColors.darkBerry, fontWeight: FontWeight.w700);
          }
          return AppTextStyles.navLabel.copyWith(color: AppColors.stone);
        }),
        elevation:   8,
        shadowColor: AppColors.darkBerry.withOpacity(0.15),
        height:      AppConstants.bottomNavHeight,
      ),

      // ── Elevated button ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBerry,
          foregroundColor: AppColors.white,
          textStyle: AppTextStyles.button,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          ),
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ── Outlined button ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkBerry,
          side: const BorderSide(color: AppColors.darkBerry, width: 1.5),
          textStyle:
              AppTextStyles.button.copyWith(color: AppColors.darkBerry),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkBerry,
          textStyle:
              AppTextStyles.button.copyWith(color: AppColors.darkBerry),
        ),
      ),

      // ── Icon button ─────────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.darkBerry,
        ),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color:     AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusL)),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical:   AppConstants.spaceS,
        ),
      ),

      // ── Input fields ────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical:   AppConstants.spaceM,
        ),
        border: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          borderSide:
              BorderSide(color: AppColors.stone.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          borderSide:
              BorderSide(color: AppColors.stone.withOpacity(0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          borderSide:
              BorderSide(color: AppColors.darkBerry, width: 1.5),
        ),
        hintStyle:  AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
        labelStyle: AppTextStyles.bodyMedium,
      ),

      // ── Slider ──────────────────────────────────────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor:   AppColors.darkBerry,
        inactiveTrackColor: AppColors.blushDark,
        thumbColor:         AppColors.darkBerry,
        overlayColor:       Color(0x207D0531),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
      ),

      // ── Switch ──────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.stone;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.darkBerry;
          return AppColors.blushDark;
        }),
      ),

      // ── Chip ────────────────────────────────────────────────────────────────
      // Non-const because labelStyle references GoogleFonts at runtime.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor:   AppColors.darkBerry,
        labelStyle:      AppTextStyles.bodySmall,
        side: const BorderSide(color: AppColors.stone, width: 0.8),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusFull)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     AppColors.blushDark,
        thickness: 0.5,
        space:     1,
      ),

      // ── Dialog ──────────────────────────────────────────────────────────────
      // Non-const because titleTextStyle / contentTextStyle reference GoogleFonts.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusXL)),
        ),
        titleTextStyle:   AppTextStyles.headlineMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      // ── Bottom sheet ────────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL),
          ),
        ),
        elevation: 16,
      ),

      // ── Snack bar ────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.darkBerry,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusM)),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Progress indicator ──────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:             AppColors.darkBerry,
        circularTrackColor: AppColors.blushDark,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Dark theme
  // ────────────────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness:   Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary:              AppColors.roseQuartz,
        onPrimary:            AppColors.white,
        primaryContainer:     AppColors.darkBerryDark,
        onPrimaryContainer:   AppColors.blush,
        secondary:            AppColors.blush,
        onSecondary:          AppColors.darkBerry,
        surface:              AppColors.surfaceDark,
        onSurface:            AppColors.blush,
        tertiary:             AppColors.sageLight,
        onTertiary:           AppColors.white,
        error:                Color(0xFFCF6679),
        onError:              AppColors.black,
        outline:              AppColors.stoneDark,
        outlineVariant:       Color(0xFF3D2429),
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.blush,
        elevation:       0,
        centerTitle:     true,
        titleTextStyle:
            AppTextStyles.headlineSmall.copyWith(color: AppColors.blush),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor:                   AppColors.transparent,
          statusBarIconBrightness:          Brightness.light,
          systemNavigationBarColor:         AppColors.backgroundDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.blush,
          size:  AppConstants.iconM,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor:  AppColors.roseQuartz.withOpacity(0.25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.roseQuartz, size: 24);
          }
          return IconThemeData(
              color: AppColors.stone.withOpacity(0.7), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.navLabel.copyWith(
                color: AppColors.roseQuartz, fontWeight: FontWeight.w700);
          }
          return AppTextStyles.navLabel.copyWith(color: AppColors.stoneDark);
        }),
        elevation: 8,
        height:    AppConstants.bottomNavHeight,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.roseQuartz,
          foregroundColor: AppColors.white,
          textStyle:       AppTextStyles.button,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      cardTheme: const CardThemeData(
        color:     AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusL)),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical:   AppConstants.spaceS,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: const Color(0xFF2A1218),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical:   AppConstants.spaceM,
        ),
        border: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          borderSide: BorderSide(
              color: AppColors.stoneDark.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          borderSide: BorderSide(
              color: AppColors.stoneDark.withOpacity(0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusM)),
          borderSide:
              BorderSide(color: AppColors.roseQuartz, width: 1.5),
        ),
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.stoneDark),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor:   AppColors.roseQuartz,
        inactiveTrackColor: Color(0xFF3D2429),
        thumbColor:         AppColors.roseQuartz,
        overlayColor:       Color(0x20B05276),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
      ),

      dividerTheme: const DividerThemeData(
        color:     Color(0xFF2A1218),
        thickness: 0.5,
        space:     1,
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusXL)),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL),
          ),
        ),
        elevation: 16,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.surfaceDark,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.blush),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(AppConstants.radiusM)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
