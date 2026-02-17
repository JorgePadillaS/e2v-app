import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Map<String, dynamic>.from(data['user'] as Map);
    final wallet = data['wallet'] as Map<String, dynamic>?;
    final tag = data['rfid_tag'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E2V App · Demo V1'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(user['name']?.toString() ?? '-'),
              subtitle: Text(user['email']?.toString() ?? '-'),
              trailing: const Chip(label: Text('Cliente')),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Wallet'),
              subtitle: Text('${wallet?['balance'] ?? '0'} ${wallet?['currency'] ?? ''}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('RFID tag'),
              subtitle: Text(tag?['tag_code']?.toString() ?? 'N/A'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Siguiente sprint:'),
          const Text('• Stations list\n• Start/Stop session\n• Wallet top-up local\n• Historial de sesiones')
        ],
      ),
    );
  }
}
