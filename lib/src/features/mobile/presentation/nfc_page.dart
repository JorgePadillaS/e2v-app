import 'sessions_page.dart';
import '../../../core/ui/maxvolt_theme.dart';
import 'live_charge_view.dart';

import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/ui/app_toast.dart';
import '../data/mobile_api.dart';
import 'qr_connector_select_page.dart';
import 'qr_scan_page.dart';
import '../application/active_session_notifier.dart';
import 'vehicle_selector.dart';
import '../../auth/presentation/vehicles_screen.dart';
import '../../auth/presentation/profile_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  bool _isPerformingAction = false;
  bool _stopping = false;
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
    final result = await Navigator.of(context)
        .push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => const QrScanPage()));

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

      final vehicleResult = await VehicleSelectorSheet.show(context, ref);
      if (!mounted) return;
      if (vehicleResult == null) {
        return; // User cancelled
      }

      final int? selectedVehicleId = vehicleResult == -1 ? null : vehicleResult;

      setState(() {
        _isPerformingAction = true;
        _loadingMessage = 'Iniciando carga...\nComunicando con el equipo';
      });

      try {
        await widget.api.startStation(stationId, connectorId: selectedConnectorId, vehicleId: selectedVehicleId);
        if (!mounted) return;

        showAppToast(context, 'Comando enviado con éxito', type: AppToastType.success);
        ref.read(activeSessionProvider.notifier).refresh();
      } catch (e) {
        if (!mounted) return;
        String errorMsg = 'Error al iniciar';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['status'] == 'vehicle_required') {
            _showVehicleRequiredDialog(context, data['message'] ?? errorMsg);
            return;
          }
          if (data is Map && data['status'] == 'billing_document_required') {
            _showBillingDocumentRequiredDialog(context, data['message'] ?? errorMsg);
            return;
          }
          errorMsg = data?['message'] ?? e.message ?? e.toString();
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

  Future<void> _showCompletedSession(int id) async {
    try {
      final completed = await widget.api.session(id);
      if (!mounted || completed['status'] != 'Completed') return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionReceiptPage(session: completed)));
    } catch (_) {
      /* The confirmed history can be opened again later. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessionAsync = ref.watch(activeSessionProvider);

    // Refresh balance when session state changes (e.g. session finished)
    ref.listen(activeSessionProvider, (prev, next) {
      if (prev?.asData?.value != null && next.hasValue && next.asData?.value == null) {
        _stopping = false;
        _checkBalance();
        final id = int.tryParse(prev?.asData?.value?['id']?.toString() ?? '');
        if (id != null) _showCompletedSession(id);
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

            if (_userBalance == null)
              return Center(
                child: FilledButton.icon(
                  onPressed: _checkBalance,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar saldo'),
                ),
              );
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
      color: Colors.black.withValues(alpha: 0.6),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 5)),
              const SizedBox(height: 32),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              const Text('Por favor espera un momento', style: TextStyle(color: Colors.grey, fontSize: 14)),
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

    return LiveChargeView(
      session: session,
      stale: ref.watch(activeSessionStaleProvider),
      stopping: _stopping,
      onStop: () => _confirmStop(context, session),
    );
  }

  Widget _buildStartingView(Map<String, dynamic> session) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Theme.of(context).colorScheme.surface, Theme.of(context).scaffoldBackgroundColor],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
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
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
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
              const SizedBox(height: 32),
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
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context, Map<String, dynamic> session) async {
    if (_stopping) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Terminamos aquí?'),
        content: const Text('Se enviará la solicitud de parada. Espera la confirmación antes de desconectar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir cargando')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar carga')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _stopping = true);
    try {
      await widget.api.stopStation((session['station_id'] as num).toInt());
      await ref.read(activeSessionProvider.notifier).refresh();
      if (!mounted) return;
      showAppToast(context, 'Solicitud enviada. Esperando confirmación del cargador.', type: AppToastType.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stopping = false);
      showAppToast(
        context,
        'No pudimos confirmar el envío. Revisa tu conexión e intenta nuevamente.',
        type: AppToastType.error,
      );
    }
  }

  void _showVehicleRequiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.orange),
            SizedBox(width: 8),
            Text('Vehículo Requerido', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiclesScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Registrar Vehículo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBillingDocumentRequiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.orange),
            SizedBox(width: 8),
            Text('Documento Requerido', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Completar Perfil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientBalanceView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
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
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningPromptView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const MaxVoltHeading(
          'Conecta.\nEscanea. Sigue.',
          eyebrow: 'Carga en tres pasos',
          subtitle: 'Usa el QR junto a la manguera de tu vehículo.',
        ),
        const SizedBox(height: 26),
        Container(
          height: 220,
          decoration: BoxDecoration(color: MaxVolt.night, borderRadius: BorderRadius.circular(26)),
          child: const Center(child: Icon(Icons.qr_code_scanner, size: 110, color: MaxVolt.lime)),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _scanQrAndStart,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear QR'),
        ),
        const SizedBox(height: 14),
        Text('Saldo app: Bs ${_userBalance?.toStringAsFixed(2) ?? '—'}', textAlign: TextAlign.center),
      ],
    );
  }
}
