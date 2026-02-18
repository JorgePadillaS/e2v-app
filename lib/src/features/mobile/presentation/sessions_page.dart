import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.api});
  final MobileApi api;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.sessions();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.sessions());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return ListView(children: const [
              SizedBox(height: 100),
              Center(child: CircularProgressIndicator()),
            ]);
          }

          final rows = (snap.data!['data'] as List?) ?? const [];
          if (rows.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              Center(child: Text('Sin sesiones registradas')),
            ]);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final s = Map<String, dynamic>.from(rows[i] as Map);
              return Card(
                child: ListTile(
                  title: Text('Tx #${s['transaction_id'] ?? s['id']}'),
                  subtitle: Text('Estado: ${s['status'] ?? '-'} · kWh: ${s['total_energy_kwh'] ?? 0} · Costo: ${s['total_cost'] ?? 0}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
