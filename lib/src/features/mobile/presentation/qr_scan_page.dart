import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final ctrl = TextEditingController();
  bool isManual = false;
  bool isScanning = true;

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
      if (part.startsWith('CP=') || part.startsWith('CB=')) {
        cb = part.split('=').last;
      }
      if (part.startsWith('CONNECTOR=') || part.startsWith('CONN=')) {
        conn = int.tryParse(part.split('=').last);
      }
    }

    return {'charge_box_id': cb, 'connector_id': conn};
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        setState(() => isScanning = false);
        final parsed = _parse(code);
        if (parsed['charge_box_id'] != null) {
          Navigator.pop(context, parsed);
          break;
        } else {
          // If not valid but we scanned, reset scanning after 2s
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => isScanning = true);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR del cargador'),
        actions: [
          IconButton(
            icon: Icon(isManual ? Icons.camera_alt : Icons.keyboard),
            onPressed: () => setState(() => isManual = !isManual),
          ),
        ],
      ),
      body:
          isManual
              ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Pega el contenido del QR del cargador.'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Contenido QR', border: OutlineInputBorder()),
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
              )
              : Stack(
                children: [
                  MobileScanner(onDetect: _onDetect),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Encuadra el código QR para escanear',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
