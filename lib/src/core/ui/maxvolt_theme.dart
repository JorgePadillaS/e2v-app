import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) => ThemeModeController());

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }
  final _storage = const FlutterSecureStorage();
  bool _changed = false;
  Future<void> _load() async {
    try {
      final value = await _storage.read(key: 'maxvolt.theme');
      if (mounted && !_changed)
        state = ThemeMode.values.firstWhere((m) => m.name == value, orElse: () => ThemeMode.system);
    } catch (_) {}
  }

  Future<void> select(ThemeMode mode) async {
    _changed = true;
    state = mode;
    try {
      await _storage.write(key: 'maxvolt.theme', value: mode.name);
    } catch (_) {}
  }
}

abstract final class MaxVolt {
  static const forest = Color(0xFF03624C),
      mint = Color(0xFF2CC295),
      lime = Color(0xFF6DF48D),
      night = Color(0xFF032221),
      paper = Color(0xFFF2F9F3);
  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: forest, brightness: brightness).copyWith(
      primary: dark ? lime : forest,
      onPrimary: dark ? night : paper,
      secondary: mint,
      onSecondary: night,
      surface: dark ? const Color(0xFF103B33) : Colors.white,
      onSurface: dark ? paper : night,
      surfaceContainerHighest: dark ? const Color(0xFF184A3C) : const Color(0xFFE4F1E7),
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? night : paper,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? night : paper,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(color: scheme.surface, elevation: 0, margin: EdgeInsets.zero, shape: rounded),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: night,
          minimumSize: const Size(48, 54),
          shape: rounded,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: night,
          elevation: 0,
          minimumSize: const Size(48, 54),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52), shape: rounded),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }
}

class MaxVoltLogo extends StatelessWidget {
  const MaxVoltLogo({super.key, this.width = 126});
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MaxVolt',
    image: true,
    child: ClipRect(
      child: SizedBox(
        width: width,
        height: width * .43,
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: width,
          maxHeight: width,
          child: Image.asset('assets/maxvolt_wordmark.png', width: width, height: width, excludeFromSemantics: true),
        ),
      ),
    ),
  );
}

class MaxVoltHeading extends StatelessWidget {
  const MaxVoltHeading(this.title, {super.key, this.eyebrow, this.subtitle});
  final String title;
  final String? eyebrow, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null)
        Text(eyebrow!.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.8)),
      const SizedBox(height: 8),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: -1.2, fontWeight: FontWeight.w500),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
}
