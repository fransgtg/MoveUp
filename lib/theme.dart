import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tema gelap bergradasi: biru malam yang dalam, dengan aksen biru elektrik
// untuk aksi dan sorotan. Tema terang tetap tersedia dengan gradasi yang lebih lembut.
class _Palette {
  const _Palette({
    required this.background,
    required this.backgroundTop,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.input,
    required this.glow,
    required this.coolGlow,
  });

  final Color background;
  // Warna di puncak layar; latar memudar dari sini ke [background]
  final Color backgroundTop;
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final Color input;
  // Cahaya hangat di pojok kanan atas dan cahaya dingin di kiri bawah
  final Color glow;
  final Color coolGlow;
}

// Skala jarak dipakai di semua layar supaya ritme tata letak seragam
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 32.0;

  // Padding tepi layar
  static const page = EdgeInsets.all(xl);
}

// Satu bentuk sudut untuk tombol, field, dan kartu
class AppRadius {
  static const control = 14.0;
  static const card = 20.0;
  static const sheet = 28.0;
}

class AppTheme {
  // Warna status; sengaja sedikit redup agar tetap serasi dengan tema monokrom
  static const danger = Color(0xFFD64545);
  static const success = Color(0xFF3F9A5C);
  static const warning = Color(0xFFE09A2B);

  // Aksen tunggal: dipakai hemat untuk aksi utama, rute, dan angka yang disorot
  // Cukup terang untuk teks di atas latar gelap, cukup gelap untuk teks putih di atasnya
  static const accent = Color(0xFF3B82F6);
  static const accentDeep = Color(0xFF2563EB);

  // Latar kartu sorotan (ringkasan minggu, header profil) dan tombol utama: biru ke nila
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDeep, Color(0xFF4F46E5)],
  );

  // Bayangan lembut untuk elemen yang mengambang
  static List<BoxShadow> softShadow(Color color, {double alpha = 0.25}) => [
        BoxShadow(color: color.withValues(alpha: alpha), blurRadius: 24, offset: const Offset(0, 10)),
      ];

  // Terang: kabut pagi
  static const _fog = _Palette(
    background: Color(0xFFEEF0F4),
    backgroundTop: Color(0xFFE8F0FE),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFDDE2EA),
    text: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    input: Color(0xFFE9EDF3),
    glow: Color(0x263B82F6),
    coolGlow: Color(0x1422D3EE),
  );

  // Gelap: biru malam
  static const _midnight = _Palette(
    background: Color(0xFF060A14),
    backgroundTop: Color(0xFF0E1A33),
    surface: Color(0xFF111A2C),
    border: Color(0xFF1F2B44),
    text: Color(0xFFEEF2F8),
    muted: Color(0xFF8B98B0),
    input: Color(0xFF16213A),
    glow: Color(0x553B82F6),
    coolGlow: Color(0x3022D3EE),
  );

  static _Palette _of(Brightness b) => b == Brightness.dark ? _midnight : _fog;

  // Latar bergradasi untuk seluruh halaman; dipasang lewat transisi halaman (lihat _GradientPages)
  static Widget background(BuildContext context, Widget child) {
    final p = _of(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.background],
          stops: const [0, 0.55],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.1, -1.05),
            radius: 1.1,
            colors: [p.glow, p.glow.withValues(alpha: 0)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.2, 1.1),
              radius: 1.2,
              colors: [p.coolGlow, p.coolGlow.withValues(alpha: 0)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  static ThemeData get lightTheme => _build(Brightness.light, _fog);

  static ThemeData get darkTheme => _build(Brightness.dark, _midnight);

  // Huruf condensed tebal untuk judul dan angka statistik, seperti poster olahraga
  static TextStyle display(double size, {Color? color, double letterSpacing = 0.5}) => GoogleFonts.barlowCondensed(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: letterSpacing,
        color: color,
      );

  static ThemeData _build(Brightness brightness, _Palette p) {
    const primary = accent;
    const onPrimary = Colors.white;
    final dark = brightness == Brightness.dark;
    final base = dark ? ThemeData.dark() : ThemeData.light();
    final body = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text);
    final condensed = GoogleFonts.barlowCondensedTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: p.text,
      onSecondary: p.surface,
      // Dipakai Material 3 untuk chip yang dipilih
      secondaryContainer: primary,
      onSecondaryContainer: onPrimary,
      error: danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      outline: p.border,
      outlineVariant: p.border,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: primary,
      // Transparan supaya latar bergradasi di belakang halaman terlihat. Pakai canvasColor
      // untuk panel yang harus solid (mis. di atas peta).
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: p.background,
      pageTransitionsTheme: _GradientPages.theme,
      dividerColor: p.border,
      textTheme: body.copyWith(
        displayLarge: condensed.displayLarge,
        displayMedium: condensed.displayMedium,
        displaySmall: condensed.displaySmall,
        headlineLarge: condensed.headlineLarge,
        headlineMedium: condensed.headlineMedium,
        headlineSmall: condensed.headlineSmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: display(22, color: p.text, letterSpacing: 1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          textStyle: const TextStyle(letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Aksi pendamping tetap monokrom supaya aksen hanya untuk aksi utama
          foregroundColor: p.text,
          side: BorderSide(color: p.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        filled: true,
        fillColor: p.input,
        labelStyle: TextStyle(color: p.muted),
        floatingLabelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600),
        errorMaxLines: 2,
        hintStyle: TextStyle(color: p.muted),
        prefixIconColor: p.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        // Sedikit tembus pandang supaya cahaya gradasi latar terasa di balik kartu
        color: p.surface.withValues(alpha: dark ? 0.82 : 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.07) : p.border, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        side: BorderSide(color: p.border),
        checkmarkColor: onPrimary,
        labelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: onPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          side: BorderSide(color: p.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
        titleTextStyle: display(24, color: p.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.surface),
        actionTextColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      popupMenuTheme: PopupMenuThemeData(color: p.surface),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
      listTileTheme: ListTileThemeData(
        iconColor: p.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onPrimary : p.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : p.input),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : p.border),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: primary,
        unselectedItemColor: p.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

// Membungkus setiap halaman dengan latar bergradasi tanpa mengubah animasi transisi bawaan
// platform. Tiap halaman punya latar sendiri, jadi saat transisi halaman lama tidak tembus.
class _GradientPages extends PageTransitionsBuilder {
  const _GradientPages(this.inner);

  final PageTransitionsBuilder inner;

  static final theme = PageTransitionsTheme(
    builders: {
      for (final e in const PageTransitionsTheme().builders.entries) e.key: _GradientPages(e.value),
    },
  );

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      inner.buildTransitions(route, context, animation, secondaryAnimation, Builder(
        builder: (context) => AppTheme.background(context, child),
      ));
}
