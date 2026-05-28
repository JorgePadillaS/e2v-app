import 'dart:async';

import 'package:flutter/material.dart';

class QrConnectorSelectPage extends StatefulWidget {
  const QrConnectorSelectPage({
    super.key,
    required this.chargeBoxId,
    required this.stationName,
    required this.connectors,
    this.initialConnectorId,
  });

  final String chargeBoxId;
  final String stationName;
  final List<Map<String, dynamic>> connectors;
  final int? initialConnectorId;

  @override
  State<QrConnectorSelectPage> createState() => _QrConnectorSelectPageState();
}

class _QrConnectorSelectPageState extends State<QrConnectorSelectPage> {
  int? _selectedConnectorId;
  bool _blink = false;
  Timer? _timer;

  bool get isConfirmationMode => widget.initialConnectorId != null;

  @override
  void initState() {
    super.initState();
    _selectedConnectorId = widget.initialConnectorId;
    _timer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      setState(() => _blink = !_blink);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _labelFor(Map<String, dynamic> c) {
    final cid = (c['connector_id'] as num?)?.toInt();
    if (cid == 1) return 'CCS2'; // Swapped: 1 = CCS2
    if (cid == 2) return 'GBT'; // Swapped: 2 = GBT

    final type = (c['type'] ?? '').toString().toUpperCase();
    if (type.contains('CCS2') || type.contains('CSS2')) return 'CCS2';
    if (type.contains('GBT') || type.contains('GB/T')) return 'GBT';
    return (c['type'] ?? 'CONECTOR').toString().toUpperCase();
  }

  String _statusRaw(Map<String, dynamic> c) => (c['status'] ?? '').toString().toUpperCase();

  bool _isError(String status) => status.contains('FAULT') || status.contains('ERROR') || status.contains('UNAVAILABLE');

  bool _isBusy(String status) =>
      status.contains('CHARG') ||
      status.contains('OCCUP') ||
      // status.contains('PREPAR') // REMOVED: Preparing means Plugged but ready
      status.contains('SUSPEND');

  bool _isPlugged(String status) => status.contains('PREPAR');

  Color _colorFor(Map<String, dynamic> c, bool selected) {
    if (selected) return Colors.green;
    final status = _statusRaw(c);
    if (_isError(status)) return Colors.red;
    if (_isBusy(status)) return Colors.amber;
    if (_isPlugged(status)) return Colors.blue; // Plugged but not charging yet
    return _blink ? Colors.grey.shade400 : Colors.grey.shade700;
  }

  bool _canSelect(Map<String, dynamic> c) {
    final status = _statusRaw(c);
    return !_isError(status) && (!_isBusy(status) || _isPlugged(status));
  }

  @override
  Widget build(BuildContext context) {
    final ccs = widget.connectors.cast<Map<String, dynamic>>().firstWhere(
      (c) => (c['connector_id'] as num?)?.toInt() == 1 || _labelFor(c) == 'CCS2',
      orElse: () => const {},
    );
    final gbt = widget.connectors.cast<Map<String, dynamic>>().firstWhere(
      (c) => (c['connector_id'] as num?)?.toInt() == 2 || _labelFor(c) == 'GBT',
      orElse: () => const {},
    );

    Widget hoseCard(Map<String, dynamic> c, String forcedLabel) {
      final exists = c.isNotEmpty;
      final connectorId = exists ? (c['connector_id'] as num?)?.toInt() : null;
      final selected = connectorId != null && connectorId == _selectedConnectorId;
      final color = exists ? _colorFor(c, selected) : Colors.grey.shade300;
      final enabled = exists && _canSelect(c);

      return Expanded(
        child: GestureDetector(
          onTap:
              enabled
                  ? () {
                    setState(() => _selectedConnectorId = connectorId);
                  }
                  : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 3),
              color: color.withValues(alpha: 0.12),
            ),
            child: Column(
              children: [
                Icon(Icons.power, size: 48, color: color),
                const SizedBox(height: 8),
                Text(forcedLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    !exists
                        ? 'SIN CONECTOR'
                        : _isError(_statusRaw(c))
                        ? 'ERROR'
                        : _isBusy(_statusRaw(c))
                        ? 'OCUPADA'
                        : _isPlugged(_statusRaw(c))
                        ? 'CONECTADO'
                        : selected
                        ? 'LISTO'
                        : 'DISPONIBLE',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isConfirmationMode ? 'Confirmar Carga' : 'Seleccionar manguera')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isConfirmationMode) ...[
                const Icon(Icons.ev_station, size: 76),
                const SizedBox(height: 8),
                Text(
                  widget.stationName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text('QR: ${widget.chargeBoxId}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                Row(children: [hoseCard(ccs, 'CCS2'), const SizedBox(width: 12), hoseCard(gbt, 'GBT')]),
                const SizedBox(height: 24),
                const Text(
                  'Leyenda: gris parpadeante = disponible · amarillo = ocupada · rojo = error · verde = seleccionada',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _selectedConnectorId == null ? null : () => Navigator.pop(context, _selectedConnectorId),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('INICIAR CARGA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                const Center(child: Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue)),
                const SizedBox(height: 32),
                const Text(
                  'Cargador detectado correctamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.stationName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Usted habilitará el dispensador:',
                        style: TextStyle(fontSize: 14, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedConnectorId == 1
                            ? 'CCS2'
                            : (_selectedConnectorId == 2 ? 'GBT' : 'CONECTOR $_selectedConnectorId'),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Presione el botón de abajo para autorizar la carga e iniciar el flujo de energía.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 80,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedConnectorId),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, size: 32),
                        SizedBox(width: 12),
                        Text('START / INICIAR', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
