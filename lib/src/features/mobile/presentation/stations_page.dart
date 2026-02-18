import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';

class StationsPage extends StatefulWidget {
  const StationsPage({super.key, required this.api});
  final MobileApi api;

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.stations();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.stations());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Error estaciones: ${snap.error}')),
            ]);
          }

          final stations = snap.data ?? [];
          if (stations.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('No hay estaciones activas')),
            ]);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: stations.length,
            itemBuilder: (_, i) {
              final s = Map<String, dynamic>.from(stations[i] as Map);
              final connectors = (s['connectors'] as List?) ?? const [];
              final stationId = (s['id'] as num).toInt();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name']?.toString() ?? 'Station', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('ChargeBox: ${s['charge_box_id'] ?? '-'}'),
                      Text('Conectores: ${connectors.length}'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final res = await widget.api.startStation(stationId);
                              if (!mounted) return;
                              messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Start enviado')));
                            },
                            child: const Text('Start'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final res = await widget.api.stopStation(stationId);
                              if (!mounted) return;
                              messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Stop enviado')));
                            },
                            child: const Text('Stop'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
