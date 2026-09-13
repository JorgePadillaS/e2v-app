import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ui/maxvolt_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class E2VApp extends ConsumerWidget {
  const E2VApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'MaxVolt',
    debugShowCheckedModeBanner: false,
    themeMode: ref.watch(themeModeProvider),
    theme: MaxVolt.theme(Brightness.light),
    darkTheme: MaxVolt.theme(Brightness.dark),
    home: const AuthGate(),
  );
}
