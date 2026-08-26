import 'package:agendamento_app/app/screens/barber_home_page.dart';
import 'package:agendamento_app/app/screens/client_home_page.dart';
import 'package:agendamento_app/app/screens/login_page_cliente.dart';
import 'package:agendamento_app/app/screens/register_page.dart';
import 'package:agendamento_app/app/screens/role_gate_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberKR',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RoleGatePage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/role': (context) => const RoleGatePage(),
        '/client': (context) => const ClientHomePage(),
        '/barber': (context) => const BarberHomePage(),
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: brightness,
    primary: isDark ? const Color(0xFF71D8C8) : const Color(0xFF0F766E),
    secondary: isDark ? const Color(0xFFFFB098) : const Color(0xFFE76F51),
    tertiary: isDark ? const Color(0xFFFFD166) : const Color(0xFFE9A922),
    surface: isDark ? const Color(0xFF131A18) : const Color(0xFFFFF9F2),
  );
  final baseTextTheme =
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
  final textTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
    headlineLarge: GoogleFonts.manrope(
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w800,
      color: colors.onSurface,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: 28,
      height: 1.12,
      fontWeight: FontWeight.w800,
      color: colors.onSurface,
    ),
    headlineSmall: GoogleFonts.manrope(
      fontSize: 23,
      height: 1.18,
      fontWeight: FontWeight.w800,
      color: colors.onSurface,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    ),
    titleSmall: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    ),
    bodyMedium: GoogleFonts.manrope(
      fontSize: 14,
      height: 1.45,
      color: colors.onSurfaceVariant,
    ),
    bodySmall: GoogleFonts.manrope(
      fontSize: 12.5,
      height: 1.4,
      color: colors.onSurfaceVariant,
    ),
    labelLarge: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: colors.outlineVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          isDark ? colors.surfaceContainerHigh : colors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.primary, width: 1.8),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      prefixIconColor: colors.onSurfaceVariant,
      suffixIconColor: colors.onSurfaceVariant,
      floatingLabelStyle: TextStyle(color: colors.primary),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 0 : 2,
      shadowColor: colors.shadow.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 52),
        elevation: 0,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: colors.outlineVariant),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: colors.surfaceContainerLowest,
      indicatorColor: colors.primaryContainer,
      elevation: 3,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? colors.primary : colors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colors.primary : colors.onSurfaceVariant,
          size: 24,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      selectedColor: colors.primaryContainer,
      side: BorderSide(color: colors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: textTheme.labelLarge?.copyWith(color: colors.onSurface),
      secondaryLabelStyle:
          textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer),
      checkmarkColor: colors.primary,
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 24,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.inverseSurface,
      contentTextStyle: TextStyle(color: colors.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
