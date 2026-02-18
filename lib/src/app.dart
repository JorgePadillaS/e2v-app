import 'package:e2v_app/src/features/auth/presentation/auth_gate.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class E2VApp extends StatelessWidget {
  const E2VApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.interTextTheme();

    return MaterialApp(
      title: 'E2V App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: FlexThemeData.light(
        scheme: FlexScheme.mandyRed,
        textTheme: baseText,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 8,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
        ),
      ).copyWith(
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          ),
        ),
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.mandyRed,
        textTheme: baseText,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
        ),
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFF12131A),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1.3),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
