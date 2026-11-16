import 'package:material_ui/material_ui.dart';

import 'theme_pack.dart';

/// Warna khusus aplikasi di luar ColorScheme Material.
///
/// Kontras sudah dicek terhadap WCAG: teks utama >= 7:1, teks sekunder >= 4.5:1,
/// teks di atas tombol utama >= 4.5:1.
@immutable
class DracinColors extends ThemeExtension<DracinColors> {
  const DracinColors({
    required this.packId,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.outline,
  });

  final ThemePackId packId;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color text;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color outline;

  @override
  DracinColors copyWith() => this;

  @override
  DracinColors lerp(ThemeExtension<DracinColors>? other, double t) {
    if (other is! DracinColors) return this;
    return DracinColors(
      packId: t < 0.5 ? packId : other.packId,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

extension DracinTheme on BuildContext {
  DracinColors get colors => Theme.of(this).extension<DracinColors>()!;
  ThemePack get pack => ThemePack.of(colors.packId);
}

/// Ukuran sentuh minimum (dp) untuk semua kontrol: lebih besar dari 48 Material.
const double kTouchTarget = 56;

ThemeData buildTheme(Brightness brightness, ThemePack pack) {
  final c = pack.colors(brightness == Brightness.dark);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.accent,
    onSecondary: c.bg,
    error: brightness == Brightness.dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    onError: c.bg,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    outline: c.outline,
    surfaceContainerHighest: c.surfaceHigh,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(color: c.text, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kTouchTarget, kTouchTarget),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(kTouchTarget, kTouchTarget),
        foregroundColor: c.text,
        side: BorderSide(color: c.outline, width: 1.5),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(kTouchTarget, kTouchTarget),
        foregroundColor: c.accent,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(kTouchTarget, kTouchTarget),
        foregroundColor: c.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.accent, width: 2.5),
      ),
      labelStyle: TextStyle(color: c.muted, fontSize: 17),
      floatingLabelStyle: TextStyle(color: c.accent, fontSize: 17, fontWeight: FontWeight.w700),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surfaceHigh,
      selectedColor: c.primary,
      checkmarkColor: c.onPrimary,
      labelStyle: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: c.onPrimary, fontSize: 17, fontWeight: FontWeight.w700),
      side: BorderSide(color: c.outline),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surfaceHigh,
      contentTextStyle: TextStyle(color: c.text, fontSize: 17),
      actionTextColor: c.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: c.outline.withValues(alpha: 0.35),
    focusColor: c.accent.withValues(alpha: 0.28),
  );
}
