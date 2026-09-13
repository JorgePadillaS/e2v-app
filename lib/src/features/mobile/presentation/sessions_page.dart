import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/maxvolt_theme.dart';
import '../data/mobile_api.dart';
import '../application/active_session_notifier.dart';

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key, required this.api, this.onActiveSession});
  final MobileApi api;
  final VoidCallback? onActiveSession;
  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.api.sessions();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.sessions());
    try {
      await _future;
    } catch (_) {
      /* FutureBuilder displays the retry state. */
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeSessionProvider, (prev, next) {
      if (prev?.asData?.value?['id'] != next.asData?.value?['id']) _reload();
    });
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final rows = (snapshot.data?['data'] as List? ?? [])
              .whereType<Map>()
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const MaxVoltHeading(
                'Cada carga cuenta.',
                eyebrow: 'Historial',
                subtitle: 'Tus últimas sesiones de carga',
              ),
              const SizedBox(height: 24),
              if (snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
              if (snapshot.hasError) ...[
                const Text('No pudimos actualizar el historial.'),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ] else if (rows.isEmpty && snapshot.connectionState == ConnectionState.done)
                const Text('Tus cargas aparecerán aquí.'),
              for (final s in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: const CircleAvatar(
                        backgroundColor: MaxVolt.lime,
                        foregroundColor: MaxVolt.night,
                        child: Icon(Icons.bolt),
                      ),
                      title: Text(
                        s['station'] is Map
                            ? s['station']['name']?.toString() ?? 'Carga #${s['id']}'
                            : 'Carga #${s['id']}',
                      ),
                      subtitle: Text('${_stateLabel(s['status'])}\n${_number(s['total_energy_kwh'])} kWh'),
                      isThreeLine: true,
                      trailing: Text('${_currency(s)} ${_number(s['total_cost'])}'),
                      onTap: () {
                        if (['Active', 'Starting'].contains(s['status']) && widget.onActiveSession != null) {
                          widget.onActiveSession!();
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SessionReceiptPage(session: s)));
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _number(Object? value) => double.tryParse(value?.toString() ?? '')?.toStringAsFixed(2) ?? '—';
String _currency(Map s) => s['currency'] == 'BOB' || s['currency'] == null ? 'Bs' : s['currency'].toString();
String _stateLabel(Object? value) => switch (value) {
  'Completed' => 'Completada',
  'Active' => 'Cargando',
  'Starting' => 'Conectando',
  'Failed' => 'No completada',
  _ => value?.toString() ?? 'Sin estado',
};

class SessionReceiptPage extends StatelessWidget {
  const SessionReceiptPage({super.key, required this.session});
  final Map<String, dynamic> session;
  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(session['start_time']?.toString() ?? '');
    final stop = DateTime.tryParse(session['stop_time']?.toString() ?? '');
    final elapsed = start != null && stop != null ? stop.difference(start) : null;
    final invoice = Uri.tryParse(session['invoice_url']?.toString() ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de carga')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          MaxVoltHeading(
            session['status'] == 'Completed' ? 'El camino sigue.' : 'Tu sesión de carga',
            eyebrow: _stateLabel(session['status']),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Energía entregada'),
            trailing: Text('${_number(session['total_energy_kwh'])} kWh'),
          ),
          ListTile(
            title: const Text('Total'),
            trailing: Text('${_currency(session)} ${_number(session['total_cost'])}'),
          ),
          if (elapsed != null && !elapsed.isNegative)
            ListTile(
              title: const Text('Duración'),
              trailing: Text('${elapsed.inMinutes} min ${elapsed.inSeconds % 60} s'),
            ),
          if (start != null) ListTile(title: const Text('Inicio'), subtitle: Text(start.toLocal().toString())),
          if (invoice != null && invoice.scheme == 'https' && invoice.host.isNotEmpty)
            FilledButton.icon(
              onPressed: () async {
                try {
                  if (!await launchUrl(invoice, mode: LaunchMode.externalApplication) && context.mounted)
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('No se pudo abrir la factura.')));
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('No se pudo abrir la factura.')));
                }
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Abrir factura'),
            ),
        ],
      ),
    );
  }
}
