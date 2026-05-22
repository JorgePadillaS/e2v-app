import 'package:e2v_app/src/features/auth/presentation/auth_gate.dart';
import 'package:e2v_app/src/core/config/branding_config.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2v_app/src/core/config/branding_provider.dart';

class E2VApp extends ConsumerWidget {
  const E2VApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(brandingProvider);

    return brandingAsync.when(
      data: (branding) => _buildApp(branding),
      loading:
          () => const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error: (e, st) {
        debugPrint('Branding error: $e');
        return _buildApp(BrandingConfig.fallback);
      },
    );
  }

  Widget _buildApp(BrandingConfig branding) {
    final platformName = branding.platformName;
    final theme = branding.branding;
    final baseText = GoogleFonts.getFont(theme.fontFamily).fontFamily;

    return MaterialApp(
      title: platformName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: FlexThemeData.light(
        colors: FlexSchemeColor(
          primary: theme.primaryColor,
          primaryContainer: theme.primaryColor.withValues(alpha: 0.2),
          secondary: theme.secondaryColor,
          secondaryContainer: theme.secondaryColor.withValues(alpha: 0.2),
          tertiary: const Color(0xFF2E7D32),
          tertiaryContainer: const Color(0xFFC8E6C9),
          appBarColor: theme.primaryColor,
        ),
        fontFamily: baseText,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 8,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
          defaultRadius: 12.0,
          outlinedButtonRadius: 12.0,
          filledButtonRadius: 12.0,
          elevatedButtonRadius: 12.0,
        ),
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
        ),
      ),
      darkTheme: FlexThemeData.dark(
        colors: FlexSchemeColor(
          primary: theme.primaryColor,
          primaryContainer: theme.primaryColor.withValues(alpha: 0.2),
          secondary: theme.secondaryColor,
          secondaryContainer: theme.secondaryColor.withValues(alpha: 0.2),
          tertiary: const Color(0xFF81C784),
          tertiaryContainer: const Color(0xFF1B5E20),
        ),
        fontFamily: baseText,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
          defaultRadius: 12.0,
        ),
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFF12131A),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
