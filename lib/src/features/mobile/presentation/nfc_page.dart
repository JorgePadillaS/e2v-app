import 'dart:async';
import 'dart:typed_data';

import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcPage extends StatefulWidget {
  const NfcPage({super.key, required this.assignedTag});
  final String assignedTag;

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  String status = 'Acerca tu móvil al cargador para habilitar la carga';
  String lastRead = '-';
  bool scanning = false;
  bool matched = false;
  bool pulse = false;
  Timer? pulseTimer;

  String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  String _norm(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), _startScan);
  }

  @override
  void dispose() {
    pulseTimer?.cancel();
    NfcManager.instance.stopSession();
    super.dispose();
  }

  void _startPulse() {
    pulseTimer?.cancel();
    pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => pulse = !pulse);
    });
  }

  void _stopPulse() {
    pulseTimer?.cancel();
    if (mounted) setState(() => pulse = false);
  }

  Future<void> _startScan() async {
    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      if (!mounted) return;
      setState(() {
        scanning = false;
        matched = false;
        status = 'NFC no disponible en este dispositivo';
      });
      showAppToast(context, 'NFC no disponible', type: AppToastType.error);
      return;
    }

    if (!mounted) return;
    setState(() {
      scanning = true;
      matched = false;
      status = 'Acerca tu móvil al cargador para habilitar la carga';
    });
    _startPulse();

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

      await NfcManager.instance.stopSession();
      if (!mounted) return;
      _stopPulse();

      setState(() {
        lastRead = uid!;
        scanning = false;
        matched = ok;
        status = ok ? 'Lectura correcta ✅ Carga habilitada' : 'Tag no coincide con la cuenta';
      });

      if (ok) {
        showAppToast(context, 'Lectura correcta', type: AppToastType.success);
      } else {
        showAppToast(context, 'Tag incorrecto', type: AppToastType.error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chargerColor = matched
        ? Colors.green
        : (scanning ? (pulse ? Colors.grey.shade400 : Colors.grey.shade700) : Colors.grey.shade600);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Pase NFC', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Center(
          child: AnimatedOpacity(
            opacity: scanning ? (pulse ? 0.45 : 1) : 1,
            duration: const Duration(milliseconds: 350),
            child: Icon(Icons.ev_station, size: 160, color: chargerColor),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text('Tag asignado: ${widget.assignedTag.isEmpty ? '-' : widget.assignedTag}'),
                const SizedBox(height: 6),
                Text('Último leído: $lastRead'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: scanning ? null : _startScan,
          icon: const Icon(Icons.nfc),
          label: const Text('Reintentar lectura NFC'),
        ),
      ],
    );
  }
}
