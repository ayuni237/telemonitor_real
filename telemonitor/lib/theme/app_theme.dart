import 'package:flutter/material.dart';

/// Semantic colours for the app, resolved against the current theme.
///
/// Screens should never reference a raw hex value. They ask for the
/// colour by its ROLE — `AppColors.card(context)`, `AppColors.primary` —
/// and this file decides what that role looks like in light and dark
/// mode. That indirection is the whole point: adding a third theme later
/// means changing this file only.
class AppColors {
  AppColors._();

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // ---------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------

  /// The navy used for app bars, primary buttons and headings.
  /// Kept identical in both modes so the brand stays recognisable and so
  /// white text on app bars remains correct without per-screen logic.
  static const Color primary = Color(0xFF1A3C6E);

  /// Primary as it should appear for TEXT on a page background. Navy on
  /// near-black is unreadable, so dark mode lightens it.
  static Color primaryText(BuildContext c) =>
      _dark(c) ? const Color(0xFF7FA8DC) : primary;

  // ---------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------

  /// The page background behind cards.
  static Color background(BuildContext c) =>
      _dark(c) ? const Color(0xFF121418) : const Color(0xFFF5F7FA);

  /// Card and sheet background.
  static Color card(BuildContext c) =>
      _dark(c) ? const Color(0xFF1C2027) : Colors.white;

  /// Input field fill — slightly offset from the card it sits on.
  static Color field(BuildContext c) =>
      _dark(c) ? const Color(0xFF262B33) : const Color(0xFFF5F7FA);

  /// Subtle tinted surface, used for accent panels and pills.
  static Color tint(BuildContext c) =>
      _dark(c) ? const Color(0xFF223049) : const Color(0xFFEEF3FA);

  /// Hairline borders around cards.
  static Color border(BuildContext c) => _dark(c)
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.grey.withValues(alpha: 0.15);

  // ---------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------

  /// Body text on a card or page background.
  static Color textPrimary(BuildContext c) =>
      _dark(c) ? const Color(0xFFE6E9EF) : const Color(0xFF2C2C2A);

  /// Labels, captions, supporting copy.
  static Color textSecondary(BuildContext c) =>
      _dark(c) ? const Color(0xFF9AA3B2) : Colors.grey[600]!;

  /// Hints and the least prominent text.
  static Color textMuted(BuildContext c) =>
      _dark(c) ? const Color(0xFF6B7484) : Colors.grey[400]!;

  // ---------------------------------------------------------------
  // Clinical status
  // ---------------------------------------------------------------
  //
  // Foregrounds keep their hue in both modes, because the mapping from
  // colour to clinical meaning must not shift. Only the backgrounds
  // change: a pale pink panel on a dark page would glare.

  static const Color danger = Color(0xFFA32D2D);
  static const Color warning = Color(0xFF854F0B);
  static const Color success = Color(0xFF3B6D11);

  /// Danger foreground, lightened in dark mode so it stays legible.
  static Color dangerText(BuildContext c) =>
      _dark(c) ? const Color(0xFFE8807F) : danger;

  static Color warningText(BuildContext c) =>
      _dark(c) ? const Color(0xFFE0B26A) : warning;

  static Color successText(BuildContext c) =>
      _dark(c) ? const Color(0xFF8FC663) : success;

  static Color dangerBg(BuildContext c) =>
      _dark(c) ? const Color(0xFF3A1F1F) : const Color(0xFFFCEBEB);

  static Color warningBg(BuildContext c) =>
      _dark(c) ? const Color(0xFF3A2E1A) : const Color(0xFFFAEEDA);

  static Color successBg(BuildContext c) =>
      _dark(c) ? const Color(0xFF1F3018) : const Color(0xFFEAF3DE);

  /// Border for an alerting card.
  static Color dangerBorder(BuildContext c) => _dark(c)
      ? const Color(0xFFA32D2D).withValues(alpha: 0.5)
      : const Color(0xFFF09595);
}

/// Light and dark [ThemeData] for the app.
///
/// These set the defaults — scaffold background, app bar, dialogs, snack
/// bars — so that widgets which do not explicitly specify a colour adapt
/// on their own.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final bg = isDark ? const Color(0xFF121418) : const Color(0xFFF5F7FA);
    final surface = isDark ? const Color(0xFF1C2027) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: brightness,
      colorScheme: scheme.copyWith(surface: surface),
      scaffoldBackgroundColor: bg,

      // App bars stay navy in both modes. This keeps the brand constant
      // and means white foreground text remains correct everywhere
      // without each screen having to reason about it.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      cardColor: surface,
      dialogTheme: DialogThemeData(backgroundColor: surface),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor:
            isDark ? const Color(0xFF7FA8DC) : AppColors.primary,
        unselectedItemColor:
            isDark ? const Color(0xFF6B7484) : Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? const Color(0xFF7FA8DC) : AppColors.primary,
      ),

      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.20),
        thickness: 0.5,
      ),
    );
  }
}
