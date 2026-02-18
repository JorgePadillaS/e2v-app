import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/mobile/presentation/nfc_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/sessions_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/stations_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/wallet_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(widget.data['user'] as Map);
    final token = widget.data['token']?.toString() ?? '';
    final api = MobileApi(token);

    final assignedTag = (widget.data['rfid_tag'] is Map)
        ? (widget.data['rfid_tag']['tag_code']?.toString() ?? '')
        : '';

    final pages = [
      StationsPage(api: api),
      WalletPage(
        api: api,
        displayName: user['name']?.toString(),
        initialBillingDocument: user['billing_document']?.toString(),
        initialBillingComplement: user['billing_complement']?.toString(),
        initialBillingRazonSocial: user['billing_razon_social']?.toString(),
      ),
      NfcPage(assignedTag: assignedTag),
      SessionsPage(api: api),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('E2V · ${user['name'] ?? 'Cliente'}'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.ev_station), label: 'Stations'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.nfc), label: 'NFC'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Sessions'),
        ],
      ),
    );
  }
}
