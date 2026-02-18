import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.api});
  final MobileApi api;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _wallet;
  late Future<Map<String, dynamic>> _tx;

  @override
  void initState() {
    super.initState();
    _wallet = widget.api.wallet();
    _tx = widget.api.walletTransactions();
  }

  Future<void> _reload() async {
    setState(() {
      _wallet = widget.api.wallet();
      _tx = widget.api.walletTransactions();
    });
    await Future.wait([_wallet, _tx]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _wallet,
            builder: (_, snap) {
              if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
              final w = snap.data!;
              return Card(
                child: ListTile(
                  title: const Text('Saldo'),
                  subtitle: Text('${w['balance'] ?? 0} ${w['currency'] ?? ''}'),
                  trailing: Text('Límite: ${w['credit_limit'] ?? 0}'),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text('Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _tx,
            builder: (_, snap) {
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
              final items = (snap.data!['data'] as List?) ?? const [];
              if (items.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Sin movimientos aún'));
              return Column(
                children: items.map((e) {
                  final it = Map<String, dynamic>.from(e as Map);
                  return Card(
                    child: ListTile(
                      title: Text('${it['type'] ?? '-'}  ${it['amount'] ?? ''}'),
                      subtitle: Text(it['description']?.toString() ?? '-'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
