import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool handled = false;

  Map<String, dynamic> _parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map) {
        return {
          'charge_box_id': j['charge_box_id']?.toString(),
          'connector_id': int.tryParse(j['connector_id']?.toString() ?? ''),
        };
      }
    } catch (_) {}

    final up = raw.toUpperCase();
    String? cb;
    int? conn;

    for (final part in up.split(RegExp(r'[;|,\s]+'))) {
      if (part.startsWith('CP=') || part.startsWith('CB=')) cb = part.split('=').last;
      if (part.startsWith('CONNECTOR=') || part.startsWith('CONN=')) conn = int.tryParse(part.split('=').last);
    }

    return {'charge_box_id': cb, 'connector_id': conn};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR del cargador')),
      body: MobileScanner(
        onDetect: (capture) {
          if (handled) return;
          final code = capture.barcodes.first.rawValue;
          if (code == null || code.isEmpty) return;
          handled = true;
          final parsed = _parse(code);
          Navigator.pop(context, parsed);
        },
      ),
    );
  }
}
