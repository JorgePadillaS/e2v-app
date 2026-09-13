import 'package:flutter/material.dart';

import '../../../core/ui/maxvolt_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: MaxVolt.forest,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaxVoltLogo(width: 250),
          SizedBox(height: 48),
          CircularProgressIndicator(color: MaxVolt.lime),
        ],
      ),
    ),
  );
}
