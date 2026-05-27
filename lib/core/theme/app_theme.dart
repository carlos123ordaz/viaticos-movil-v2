import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Context-aware color accessor ──────────────────────────────────────────────
extension AppThemeContext on BuildContext {
  AppColors get appColors => AppColors.of(this);
}

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceTinted;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color muted2;
  final Color line;

  const AppColors._({
    required this.background,
    required this.surface,
    required this.surfaceTinted,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.muted2,
    required this.line,
  });

  static const lightColors = AppColors._(
    background: AppTheme.background,
    surface: AppTheme.surface,
    surfaceTinted: AppTheme.surfaceTinted,
    ink: AppTheme.ink,
    ink2: AppTheme.ink2,
    muted: AppTheme.muted,
    muted2: AppTheme.muted2,
    line: AppTheme.line,
  );

  static const darkColors = AppColors._(
    background: AppTheme.darkBg,
    surface: AppTheme.darkSurface,
    surfaceTinted: AppTheme.darkSurfaceTinted,
    ink: AppTheme.darkInk,
    ink2: AppTheme.darkInk2,
    muted: AppTheme.darkMuted,
    muted2: AppTheme.darkMuted2,
    line: AppTheme.darkLine,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? darkColors : lightColors);

  @override
  AppColors copyWith({
    Color? background, Color? surface, Color? surfaceTinted,
    Color? ink, Color? ink2, Color? muted, Color? muted2, Color? line,
  }) => AppColors._(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceTinted: surfaceTinted ?? this.surfaceTinted,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    muted: muted ?? this.muted,
    muted2: muted2 ?? this.muted2,
    line: line ?? this.line,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors._(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceTinted: Color.lerp(surfaceTinted, other.surfaceTinted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

class AppTheme {
  // ── Primary ──────────────────────────────────────────────
  static const Color primary = Color(0xFF3B5BFF);
  static const Color primaryDark = Color(0xFF2F49D9);
  static const Color primaryContainer = Color(0xFFE7ECFF);

  // ── Success / Secondary ───────────────────────────────────
  static const Color secondary = Color(0xFF1FB57A);
  static const Color secondaryContainer = Color(0xFFD5F3E5);

  // ── Danger / Error ────────────────────────────────────────
  static const Color error = Color(0xFFFF5C7A);
  static const Color errorContainer = Color(0xFFFFDDE4);

  // ── Surfaces ──────────────────────────────────────────────
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceTinted = Color(0xFFEEF1F8);

  // ── Text ──────────────────────────────────────────────────
  static const Color ink = Color(0xFF0E1330);
  static const Color ink2 = Color(0xFF2A2F4E);
  static const Color muted = Color(0xFF6B7290);
  static const Color muted2 = Color(0xFF9AA0BC);
  static const Color line = Color(0xFFE4E7F0);

  // ── Accents ───────────────────────────────────────────────
  static const Color yellow = Color(0xFFFFD66B);
  static const Color yellowDeep = Color(0xFFE8A93C);
  static const Color yellowTint = Color(0xFFFFF3CC);
  static const Color sky = Color(0xFF7FB3FF);
  static const Color skyTint = Color(0xFFE2EFFF);
  static const Color violet = Color(0xFF8B6BFF);
  static const Color violetTint = Color(0xFFE8E0FF);
  static const Color mint = Color(0xFF5DD8B9);
  static const Color mintTint = Color(0xFFD5F5EC);
  static const Color coral = Color(0xFFFF8A65);
  static const Color coralTint = Color(0xFFFFE3D6);
  static const Color warn = Color(0xFFFFA63D);
  static const Color warnTint = Color(0xFFFFEAC9);

  // ── Shadows ───────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A0E1330), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0E1330), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> fabShadow = [
    BoxShadow(color: Color(0x593B5BFF), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> blueShadow = [
    BoxShadow(color: Color(0x403B5BFF), blurRadius: 30, offset: Offset(0, 10)),
  ];

  // ── Dark palette ──────────────────────────────────────────
  static const Color darkBg = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF161922);
  static const Color darkSurfaceTinted = Color(0xFF1C2030);
  static const Color darkInk = Color(0xFFEEF0F8);
  static const Color darkInk2 = Color(0xFFCCD2E6);
  static const Color darkMuted = Color(0xFF7B85A0);
  static const Color darkMuted2 = Color(0xFF4E5670);
  static const Color darkLine = Color(0xFF252A38);

  static ThemeData dark() {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: darkInk),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: darkInk),
      displaySmall: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: darkInk),
      headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: darkInk),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: darkInk),
      headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: darkInk),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: darkInk),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: darkInk),
      titleSmall: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: darkInk),
      bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: darkInk2),
      bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: darkMuted),
      bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: darkMuted2),
      labelLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1, color: darkInk),
      labelMedium: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: darkMuted),
      labelSmall: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: darkMuted2, letterSpacing: 0.4),
    );

    return ThemeData(
      useMaterial3: true,
      extensions: const [AppColors.darkColors],
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF1E2D5A),
        onPrimaryContainer: const Color(0xFFB3C4FF),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFF0F3D2A),
        onSecondaryContainer: const Color(0xFF6FDFB0),
        error: error,
        onError: Colors.white,
        errorContainer: const Color(0xFF3D1020),
        onErrorContainer: const Color(0xFFFFAFBD),
        surface: darkBg,
        onSurface: darkInk,
        outline: darkLine,
        outlineVariant: darkSurfaceTinted,
        shadow: const Color(0x40000000),
        scrim: const Color(0x70000000),
        inverseSurface: darkInk,
        onInverseSurface: darkBg,
        inversePrimary: primaryContainer,
        surfaceTint: primary,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: darkInk,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: darkInk),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: darkLine, width: 1.5),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkLine, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(color: darkMuted2, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.plusJakartaSans(color: darkMuted, fontWeight: FontWeight.w600),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceTinted,
        selectedColor: const Color(0xFF1E2D5A),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: darkInk),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        height: 64,
        indicatorColor: const Color(0xFF1E2D5A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: primary);
          }
          return GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: darkMuted2);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: darkMuted2, size: 22);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
      dividerTheme: const DividerThemeData(
        color: darkLine,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: darkBg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        modalElevation: 0,
        shadowColor: Color(0x40000000),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: ink),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: ink),
      displaySmall: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: ink),
      headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: ink),
      headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: ink),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: ink),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      titleSmall: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: ink2),
      bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: muted),
      bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: muted2),
      labelLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      labelMedium: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
      labelSmall: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.4),
    );

    return ThemeData(
      useMaterial3: true,
      extensions: const [AppColors.lightColors],
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: primaryDark,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: const Color(0xFF0F7E54),
        error: error,
        onError: Colors.white,
        errorContainer: errorContainer,
        onErrorContainer: const Color(0xFFAA1F3B),
        surface: background,
        onSurface: ink,
        outline: line,
        outlineVariant: surfaceTinted,
        shadow: const Color(0x1A0E1330),
        scrim: const Color(0x420E1330),
        inverseSurface: ink,
        onInverseSurface: Colors.white,
        inversePrimary: skyTint,
        surfaceTint: primary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: line, width: 1.5),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(color: muted2, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.plusJakartaSans(color: muted, fontWeight: FontWeight.w600),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceTinted,
        selectedColor: primaryContainer,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 64,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: primary);
          }
          return GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: muted2);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: muted2, size: 22);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        modalElevation: 0,
        shadowColor: Color(0x1A0E1330),
      ),
    );
  }
}
