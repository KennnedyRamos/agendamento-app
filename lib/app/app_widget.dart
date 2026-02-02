import 'package:agendamento_app/app/screens/login_page_cliente.dart';
import 'package:agendamento_app/app/screens/register_page.dart';
import 'package:agendamento_app/app/screens/role_gate_page.dart';
import 'package:agendamento_app/app/screens/client_home_page.dart';
import 'package:agendamento_app/app/screens/barber_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberPro',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
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

ThemeData _buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F6F78),
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF1F6F78),
    onPrimary: Colors.white,
    secondary: const Color(0xFF0F3D44),
    onSecondary: Colors.white,
    tertiary: const Color(0xFF4FB8C1),
    onTertiary: const Color(0xFF001214),
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF101418),
    outline: const Color(0xFFD5D8DC),
    shadow: const Color(0x33000000),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: GoogleFonts.poppinsTextTheme(),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary.withValues(alpha: 0.18),
      side: BorderSide(color: colorScheme.outline),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      checkmarkColor: colorScheme.primary,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      elevation: 2,
      shadowColor: colorScheme.shadow,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    dividerColor: colorScheme.outline,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.onSurface,
      contentTextStyle: TextStyle(color: colorScheme.surface),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF58C7D2),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF58C7D2),
    onPrimary: const Color(0xFF001214),
    secondary: const Color(0xFF2F8A93),
    onSecondary: const Color(0xFF001214),
    tertiary: const Color(0xFF7FE0EA),
    onTertiary: const Color(0xFF001214),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    surface: const Color(0xFF111A1E),
    onSurface: const Color(0xFFE6EEF0),
    outline: const Color(0xFF2B3A40),
    shadow: const Color(0x66000000),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary.withValues(alpha: 0.22),
      side: BorderSide(color: colorScheme.outline),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      checkmarkColor: colorScheme.primary,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      elevation: 2,
      shadowColor: colorScheme.shadow,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    dividerColor: colorScheme.outline,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.onSurface,
      contentTextStyle: TextStyle(color: colorScheme.surface),
    ),
  );
}
