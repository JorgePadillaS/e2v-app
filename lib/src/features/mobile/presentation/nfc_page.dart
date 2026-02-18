import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcPage extends StatefulWidget {
  const NfcPage({super.key, required this.assignedTag});
  final String assignedTag;

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  String status = 'Listo para escanear';
  String lastRead = '-';
  bool scanning = false;

  String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  String _norm(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<void> _startScan() async {
    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      setState(() => status = 'NFC no disponible en este dispositivo');
      return;
    }

    setState(() {
      scanning = true;
      status = 'Acerca el celular al lector/tag NFC...';
    });

    NfcManager.instance.startSession(onDiscovered: (tag) async {
      String? uid;

      final data = tag.data;
      if (data['nfca']?['identifier'] != null) {
        uid = _hex(Uint8List.fromList(List<int>.from(data['nfca']['identifier'])));
      } else if (data['mifareclassic']?['identifier'] != null) {
        uid = _hex(Uint8List.fromList(List<int>.from(data['mifareclassic']['identifier'])));
      } else if (data['mifareultralight']?['identifier'] != null) {
        uid = _hex(Uint8List.fromList(List<int>.from(data['mifareultralight']['identifier'])));
      }

      uid ??= 'UNKNOWN';

      final ok = _norm(uid) == _norm(widget.assignedTag);

      if (mounted) {
        setState(() {
          lastRead = uid!;
          status = ok
              ? '✅ Tag válido para esta cuenta'
              : '❌ Tag leído no coincide con el asignado';
          scanning = false;
        });
      }

      await NfcManager.instance.stopSession();
    });
  }

  Future<void> _stopScan() async {
    await NfcManager.instance.stopSession();
    if (!mounted) return;
    setState(() {
      scanning = false;
      status = 'Escaneo detenido';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('NFC', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Tag asignado a tu cuenta'),
            subtitle: Text(widget.assignedTag.isEmpty ? 'Sin tag asignado' : widget.assignedTag),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Último tag leído'),
            subtitle: Text(lastRead),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Estado'),
            subtitle: Text(status),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: scanning ? null : _startScan,
                icon: const Icon(Icons.nfc),
                label: const Text('Escanear NFC'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: scanning ? _stopScan : null,
                icon: const Icon(Icons.stop),
                label: const Text('Detener'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
