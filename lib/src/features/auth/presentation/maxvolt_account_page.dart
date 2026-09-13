import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/maxvolt_theme.dart';
import '../application/auth_controller.dart';
import 'profile_screen.dart';
import 'vehicles_screen.dart';
import '../../mobile/data/mobile_api.dart';
import '../../mobile/presentation/notifications_page.dart';

class MaxVoltAccountPage extends ConsumerWidget {
  const MaxVoltAccountPage({super.key, required this.api, required this.openWallet});
  final MobileApi api;
  final VoidCallback openWallet;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?['user'] as Map? ?? {};
    final name = user['name']?.toString().split(' ').first ?? '';
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil y ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: MaxVoltHeading('Hola, $name.', eyebrow: 'Tu cuenta MaxVolt')),
              const CircleAvatar(
                radius: 28,
                backgroundColor: MaxVolt.lime,
                foregroundColor: MaxVolt.night,
                child: Icon(Icons.person_outline),
              ),
            ],
          ),
          const SizedBox(height: 26),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: const Text('Datos personales y facturación'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const ProfileScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('Mis vehículos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const VehiclesScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.credit_card),
            title: const Text('Tarjetas y saldo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: openWallet,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(NotificationsPage(api: api)),
          ),
          const Divider(height: 32),
          const Text('Apariencia'),
          const SizedBox(height: 14),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (values) => ref.read(themeModeProvider.notifier).select(values.first),
          ),
        ],
      ),
    );
  }
}
