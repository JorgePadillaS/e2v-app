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
    final type = (c['type'] ?? '').toString().toUpperCase();
    if (type.contains('CCS2') || type.contains('CSS2')) return 'CCS2';
    if (type.contains('GBT') || type.contains('GB/T')) return 'GBT';
    return (c['type'] ?? 'CONECTOR').toString().toUpperCase();
  }

  String _statusRaw(Map<String, dynamic> c) => (c['status'] ?? '').toString().toUpperCase();

  bool _isError(String status) => status.contains('FAULT') || status.contains('ERROR') || status.contains('UNAVAILABLE');
  bool _isBusy(String status) => status.contains('CHARG') || status.contains('OCCUP') || status.contains('PREPAR') || status.contains('SUSPEND');

  Color _colorFor(Map<String, dynamic> c, bool selected) {
    if (selected) return Colors.green;
    final status = _statusRaw(c);
    if (_isError(status)) return Colors.red;
    if (_isBusy(status)) return Colors.amber;
    return _blink ? Colors.grey.shade400 : Colors.grey.shade700;
  }

  bool _canSelect(Map<String, dynamic> c) {
    final status = _statusRaw(c);
    return !_isError(status) && !_isBusy(status);
  }

  @override
  Widget build(BuildContext context) {
    final ccs = widget.connectors.cast<Map<String, dynamic>>().firstWhere(
          (c) => _labelFor(c) == 'CCS2',
          orElse: () => const {},
        );
    final gbt = widget.connectors.cast<Map<String, dynamic>>().firstWhere(
          (c) => _labelFor(c) == 'GBT',
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
          onTap: enabled
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
                const SizedBox(height: 8),
                Text(
                  !exists
                      ? 'No disponible'
                      : _isError(_statusRaw(c))
                          ? 'ERROR'
                          : _isBusy(_statusRaw(c))
                              ? 'OCUPADA'
                              : selected
                                  ? 'SELECCIONADA'
                                  : 'DISPONIBLE',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar manguera')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedConnectorId == null ? null : () => Navigator.pop(context, _selectedConnectorId),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar carga'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.ev_station, size: 76),
            const SizedBox(height: 8),
            Text(widget.stationName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text('QR: ${widget.chargeBoxId}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                hoseCard(ccs, 'CCS2'),
                const SizedBox(width: 12),
                hoseCard(gbt, 'GBT'),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Leyenda: gris parpadeante = disponible · amarillo = ocupada · rojo = error · verde = seleccionada', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
