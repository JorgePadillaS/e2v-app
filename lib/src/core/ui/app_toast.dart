import 'package:flutter/material.dart';

enum AppToastType { success, error, warning, info }

void showAppToast(BuildContext context, String message, {AppToastType type = AppToastType.info, int duration = 3}) {
  final color = switch (type) {
    AppToastType.success => Colors.green,
    AppToastType.error => Colors.red,
    AppToastType.warning => Colors.amber.shade700,
    AppToastType.info => Colors.blueGrey,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(seconds: duration),
    ),
  );
}
