import 'package:flutter/material.dart';

/// Exact 1:1 copy of ui/theme/Color.kt's named palette, plus the inline Color(0x..) literals used
/// throughout the Kotlin screens. Every hex value here matches the Kotlin source exactly.
class AppColors {
  // ui/theme/Color.kt
  static const cream = Color(0xFFFFFDD0);
  static const softLavender = Color(0xFFE6E6FA);
  static const pastelPink = Color(0xFFFFD1DC);
  static const mintGreen = Color(0xFFBFFFC7);
  static const softBlue = Color(0xFFAEC6CF);
  static const warmWhite = Color(0xFFF5F5F5);
  static const lightShadow = Color(0xFFFFFFFF);
  static const darkShadow = Color(0xFFBEBEBE);

  // Semantic aliases used across the port (same underlying colors as above).
  static const primaryAccent = softBlue; // buttons, links, accents
  static const backgroundNeutral = warmWhite; // screen backgrounds
  static const avatarLavender = softLavender; // avatar placeholder circles / "me" chat bubble
  static const successGreen = mintGreen; // Post Pantun FAB, selected chip
  static const cardWhite = Colors.white;

  // Semantic text tier, chosen for WCAG AA contrast on white/warmWhite (~4.5:1+). The pastel
  // palette above was designed for backgrounds/shadows/tinted surfaces - it reads as ~1.8:1 to
  // ~2.7:1 when used as text or icon foreground, which is why the wordmark, primary buttons, and
  // secondary/caption text were hard to read. Use these instead of raw Colors.grey or the pastel
  // constants whenever the color is the foreground of text or a meaningful icon.
  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF5F6368); // replaces bare Colors.grey (~7:1 vs ~2.7:1)

  // Deeper counterparts of the brand pastels for use as *foreground* (text/icon/button
  // background-with-white-text) rather than background/shadow fills. Same hue family, just dark
  // enough to clear 4.5:1 (text) / 3:1 (icons) against white or warmWhite.
  static const primaryAccentStrong = Color(0xFF3D6B85); // ~5.8:1 with white text
  static const pastelPinkStrong = Color(0xFFD6537D); // ~4:1 on white, for the like icon
  static const mintGreenStrong = Color(0xFF2F9E44); // ~3.4:1 on white, for icons on a mint tint

  // MaterialTheme.kt's DarkColorScheme surfaces
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
}

class AppTheme {
  // Mirrors ui/theme/Theme.kt's LightColorScheme/DarkColorScheme (primary=SoftBlue,
  // secondary=SoftLavender, tertiary=MintGreen).
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.warmWhite,
      colorScheme: const ColorScheme.light(
        primary: AppColors.softBlue,
        secondary: AppColors.softLavender,
        tertiary: AppColors.mintGreen,
        background: AppColors.warmWhite,
        surface: Colors.white,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: Colors.black,
        onSurface: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmWhite,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.softBlue,
        secondary: AppColors.softLavender,
        tertiary: AppColors.mintGreen,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
