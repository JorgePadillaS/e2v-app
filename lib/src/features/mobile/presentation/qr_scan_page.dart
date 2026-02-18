import 'dart:convert';

import 'package:flutter/material.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final ctrl = TextEditingController();

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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pega el contenido del QR del cargador para continuar.'),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Contenido QR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final parsed = _parse(ctrl.text.trim());
                Navigator.pop(context, parsed);
              },
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Procesar QR'),
            ),
          ],
        ),
      ),
    );
  }
}
