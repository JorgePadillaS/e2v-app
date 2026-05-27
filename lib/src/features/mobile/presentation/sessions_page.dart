import 'dart:async';
import 'package:flutter/material.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2v_app/src/features/mobile/application/active_session_notifier.dart';

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key, required this.api});
  final MobileApi api;

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  late Future<Map<String, dynamic>> _future;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initData();
    _startPolling();
  }

  void _initData() {
    _future = widget.api.sessions();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _initData());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeSessionProvider, (_, __) {
      _reload();
    });
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = (snap.data?['data'] as List?) ?? const [];

          if (rows.isEmpty && snap.connectionState != ConnectionState.waiting) {
            return ListView(children: const [SizedBox(height: 100), Center(child: Text('Sin sesiones registradas'))]);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final s = Map<String, dynamic>.from(rows[i] as Map);
              final status = s['status']?.toString() ?? '';

              if (status == 'Active') {
                return _ActiveSessionCard(session: s);
              }

              if (status == 'Starting') {
                return _StartingSessionCard(session: s, onCancel: () => _reload());
              }

              return _HistorySessionCard(session: s);
            },
          );
        },
      ),
    );
  }
}

class _StartingSessionCard extends ConsumerWidget {
  const _StartingSessionCard({required this.session, required this.onCancel});
  final Map<String, dynamic> session;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //final sessionId = session['id'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.blue.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 16),
                const Expanded(child: Text('Iniciando carga...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'SOLICITADO',
                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Comunicando con el cargador. Por favor, asegúrate de haber conectado el cable correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _handleCancel(context, ref),
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('CANCELAR SOLICITUD'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('¿Cancelar solicitud?'),
            content: const Text(
              'Si el cargador no responde, puedes cancelar la solicitud para intentar nuevamente o usar otro conector.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('VOLVER')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final api = (context.findAncestorStateOfType<_SessionsPageState>()?.widget.api);
                  if (api != null) {
                    try {
                      await api.cancelSession(session['id']);
                      ref.read(activeSessionProvider.notifier).refresh();
                      onCancel();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('No se pudo cancelar la solicitud.')));
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }
}

class _ActiveSessionCard extends ConsumerWidget {
  const _ActiveSessionCard({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = Map<String, dynamic>.from(session['current_metrics'] ?? {});
    final power = metrics['power_kw'] ?? 0.0;
    final energy = metrics['energy_kwh'] ?? 0.0;
    final soc = metrics['soc'];
    final cost = session['total_cost'] ?? 0.0;

    final startTime = DateTime.tryParse(session['start_time'] ?? '') ?? DateTime.now();
    final elapsed = DateTime.now().difference(startTime);

    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.green, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                const Expanded(child: Text('Carga en Progreso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                  child: const Text('ACTIVA', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MetricItem(label: 'Potencia', value: '$power', unit: 'kW', icon: Icons.speed),
                _MetricItem(label: 'Energía', value: '$energy', unit: 'kWh', icon: Icons.electric_bolt),
                _MetricItem(label: 'Batería', value: soc != null ? '$soc' : '-', unit: '%', icon: Icons.battery_charging_full),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Costo Actual', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('Bs $cost', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Tiempo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('${elapsed.inMinutes} min', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmStop(context, ref),
                icon: const Icon(Icons.stop_circle, color: Colors.white),
                label: const Text('DETENER CARGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'El cargador se detendrá automáticamente al completar.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmStop(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('¿Detener carga?'),
            content: const Text('Se enviará la orden de parada al cargador y se realizará el ajuste final de tu saldo.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final api = (context.findAncestorStateOfType<_SessionsPageState>()?.widget.api);
                  if (api != null) {
                    api.stopStation(session['station_id']).then((_) {
                      ref.read(activeSessionProvider.notifier).refresh();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden de parada enviada.')));
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('SÍ, DETENER', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(session['start_time'] ?? '')?.toLocal();
    final end = DateTime.tryParse(session['stop_time'] ?? '')?.toLocal();
    final energy = session['total_energy_kwh'] ?? 0.0;
    final cost = session['total_cost'] ?? 0.0;

    String fmt(DateTime? d) => d == null ? '-' : '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.history, color: Colors.white)),
        title: Text('Tx #${session['transaction_id'] ?? session['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Inicio: ${fmt(start)}'),
            Text('Fin: ${fmt(end)}'),
            Text('Energía: $energy kWh · Costo: Bs $cost'),
          ],
        ),
        isThreeLine: true,
        trailing:
            (session['invoice_url'] != null)
                ? IconButton(
                  icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                  onPressed: () async {
                    final url = Uri.parse(session['invoice_url']);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                )
                : null,
      ),
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
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
