import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:typed_data';

import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/mobile/presentation/qr_connector_select_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/qr_scan_page.dart';
import 'package:e2v_app/src/features/mobile/application/active_session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NfcPage extends ConsumerStatefulWidget {
  const NfcPage({super.key, required this.assignedTag, required this.api});
  final String assignedTag;
  final MobileApi api;

  @override
  ConsumerState<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends ConsumerState<NfcPage> {
  // Balance Validation
  double? _userBalance;
  bool _loadingBalance = true;
  final double _minSafeBalance = 15.0;
  bool _isPerformingAction = false, _isIOS = false;
  String _loadingMessage = 'Procesando...';

  @override
  void initState() {
    super.initState();
    _checkBalance();
  }

  Future<void> _checkBalance() async {
    if (!mounted) return;
    setState(() => _loadingBalance = true);
    try {
      final wallet = await widget.api.wallet();
      if (mounted) {
        setState(() {
          _userBalance = double.tryParse(wallet['app_balance']?.toString() ?? '0') ?? 0;
          _loadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _scanQrAndStart() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );

    if (!mounted || result == null) return;
    final chargeBoxId = (result['charge_box_id'] ?? '').toString();
    final initialConnectorId = result['connector_id'] as int?;

    setState(() {
      _isPerformingAction = true;
      _loadingMessage = 'Buscando cargador...';
    });

    try {
      final match = await widget.api.lookupStation(chargeBoxId);
      if (!mounted) return;
      setState(() => _isPerformingAction = false);

      final stationId = (match['id'] as num).toInt();
      final connectors = ((match['connectors'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final selectedConnectorId = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => QrConnectorSelectPage(
            chargeBoxId: chargeBoxId,
            stationName: match['name']?.toString() ?? 'Estación',
            connectors: connectors,
            initialConnectorId: initialConnectorId,
          ),
        ),
      );

      if (!mounted || selectedConnectorId == null) return;

      setState(() {
        _isPerformingAction = true;
        _loadingMessage = 'Iniciando carga...\nComunicando con el equipo';
      });

      try {
        await widget.api.startStation(stationId, connectorId: selectedConnectorId);
        if (!mounted) return;
        
        showAppToast(context, 'Comando enviado con éxito', type: AppToastType.success);
        ref.read(activeSessionProvider.notifier).refresh();
      } catch (e) {
        if (!mounted) return;
        String errorMsg = 'Error al iniciar';
        if (e is DioException) {
          errorMsg = e.response?.data?['message'] ?? e.message ?? e.toString();
        }
        showAppToast(context, errorMsg, type: AppToastType.error);
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'No se encontró el cargador';
      if (e is DioException) {
        errorMsg = e.response?.data?['message'] ?? e.message ?? e.toString();
      }
      showAppToast(context, errorMsg, type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessionAsync = ref.watch(activeSessionProvider);
    _isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    // Refresh balance when session state changes (e.g. session finished)
    ref.listen(activeSessionProvider, (prev, next) {
      if (prev?.value != next.value) {
        _checkBalance();
      }
    });

    return Stack(
      children: [
        activeSessionAsync.when(
          data: (session) {
            if (session != null) {
              return _buildActiveSessionView(session);
            }

            if (_loadingBalance) {
              return const Center(child: CircularProgressIndicator());
            }

            final hasBalance = (_userBalance ?? 0) >= _minSafeBalance;
            if (!hasBalance) {
              return _buildInsufficientBalanceView();
            }

            return _buildScanningPromptView();
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error: $e')),
        ),
        if (_isPerformingAction) _buildActionOverlay(),
      ],
    );
  }

  Widget _buildActionOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(strokeWidth: 5),
              ),
              const SizedBox(height: 32),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Por favor espera un momento',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionView(Map<String, dynamic> session) {
    final status = session['status']?.toString() ?? '';
    
    if (status == 'Starting') {
      return _buildStartingView(session);
    }

    final metrics = Map<String, dynamic>.from(session['current_metrics'] ?? {});
    final power = metrics['power_kw'] ?? 0.0;
    final energy = metrics['energy_kwh'] ?? 0.0;
    final soc = metrics['soc'];
    final cost = session['total_cost'] ?? 0.0;
    
    final startTime = DateTime.tryParse(session['start_time'] ?? '') ?? DateTime.now();
    final elapsed = DateTime.now().difference(startTime);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Carga Activa', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Card(
          elevation: 12,
          shadowColor: Colors.green.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.green.shade200, width: 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)],
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt, color: Colors.green, size: 32),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TIEMPO TRANSCURRIDO', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        Text('${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MetricItem(label: 'Potencia', value: '$power', unit: 'kW', icon: Icons.speed),
                    _MetricItem(label: 'Energía', value: '$energy', unit: 'kWh', icon: Icons.electric_bolt),
                    _MetricItem(label: 'Batería', value: soc != null ? '$soc' : '-', unit: '%', icon: Icons.battery_charging_full),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(thickness: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COSTO ACUMULADO', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        Text('Bs $cost', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green)),
                      ],
                    ),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _confirmStop(context, session),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stop_circle_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('DETENER', style: TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'La carga se detendrá automáticamente si el vehículo completa su capacidad.',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartingView(Map<String, dynamic> session) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  ),
                ),
                const Icon(Icons.bolt, size: 64, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              'Estableciendo Conexión',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Estamos comunicando con el cargador inteligente.\nPor favor, asegúrate de que el cable esté bien conectado al vehículo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Este proceso puede tardar hasta 30 segundos dependiendo de la estación.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await widget.api.cancelSession(session['id']);
                    ref.read(activeSessionProvider.notifier).refresh();
                  } catch (_) {}
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.close),
                label: const Text('CANCELAR SOLICITUD', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmStop(BuildContext context, Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Detener carga?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Se enviará la orden de parada al cargador. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text('VOLVER', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.api.stopStation(session['station_id']).then((_) {
                ref.read(activeSessionProvider.notifier).refresh();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('DETENER CARGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientBalanceView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.orange),
          ),
          const SizedBox(height: 32),
          const Text(
            'Saldo Insuficiente',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tu saldo actual (Bs ${_userBalance?.toStringAsFixed(2)}) es menor al mínimo requerido para iniciar (Bs $_minSafeBalance).',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _checkBalance(),
              icon: const Icon(Icons.refresh),
              label: const Text('RE-VERIFICAR SALDO', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningPromptView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Cargar', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.wallet, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text('Saldo disponible: Bs ${_userBalance?.toStringAsFixed(2)}', 
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 60),
        Center(
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.withOpacity(0.1), width: 2),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, size: 100, color: Colors.blue),
          ),
        ),
        SizedBox(height: _isIOS ? 12 : 48),
        const Text(
          '¿Listo para cargar?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const Text(
          'Escanea el código QR ubicado en el cargador para iniciar el suministro de energía a tu vehículo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.blueGrey, height: 1.4),
        ),
        SizedBox(height: _isIOS ? 30 : 60),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            onPressed: _scanQrAndStart,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            label: const Text('ESCANEAR QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.label, required this.value, required this.unit, required this.icon});
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blueGrey.shade700, size: 22),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade400, letterSpacing: 0.2)),
      ],
    );
  }
}
