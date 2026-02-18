import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.api});
  final MobileApi api;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _wallet;
  late Future<Map<String, dynamic>> _tx;
  final amountCtrl = TextEditingController(text: '10');

  Future<void> _openLibelula(double amount) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final res = await widget.api.libelulaCheckout(amount);
      if (!mounted) return;
      final url = res['payment_url']?.toString() ?? '';
      final qr = res['qr_image']?.toString() ?? '';

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Pago Libélula BOB ${amount.toStringAsFixed(2)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (qr.isNotEmpty) ...[
                  const Text('QR de pago:'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      qr,
                      height: 220,
                      width: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Text('No se pudo cargar el QR.'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text('Link pasarela (tarjetas / QR):'),
                const SizedBox(height: 6),
                SelectableText(url.isEmpty ? 'No llegó URL de pago' : url),
              ],
            ),
          ),
          actions: [
            if (url.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: url));
                  messenger.showSnackBar(const SnackBar(content: Text('Link copiado')));
                },
                child: const Text('Copiar link'),
              ),
            if (url.isNotEmpty)
              FilledButton(
                onPressed: () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Abrir pago'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      var msg = 'Error creando pago Libélula';
      final raw = e.toString();
      if (raw.contains('LIBELULA_APP_KEY no configurada')) {
        msg = 'Libélula no está configurado aún en servidor (falta API key).';
      } else if (raw.contains('422')) {
        msg = 'Libélula rechazó la solicitud (422). Revisaré configuración/API key.';
      }
      m.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  double _manualAmount() {
    return double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _wallet = widget.api.wallet();
    _tx = widget.api.walletTransactions();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
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
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto manual (BOB)',
              hintText: 'Ej: 35.5',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  final amount = _manualAmount();
                  if (amount <= 0) {
                    m.showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
                    return;
                  }
                  await widget.api.topup(amount);
                  await _reload();
                  if (!mounted) return;
                  m.showSnackBar(SnackBar(content: Text('Recarga local +$amount aplicada')));
                },
                child: const Text('Local manual'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  final amount = _manualAmount();
                  if (amount <= 0) {
                    m.showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
                    return;
                  }
                  await _openLibelula(amount);
                },
                child: const Text('Libélula manual'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  await widget.api.topup(10);
                  await _reload();
                  if (!mounted) return;
                  m.showSnackBar(const SnackBar(content: Text('Recarga local +10 aplicada')));
                },
                child: const Text('Local +10'),
              ),
              FilledButton(
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  await widget.api.topup(20);
                  await _reload();
                  if (!mounted) return;
                  m.showSnackBar(const SnackBar(content: Text('Recarga local +20 aplicada')));
                },
                child: const Text('Local +20'),
              ),
              FilledButton(
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  await widget.api.topup(50);
                  await _reload();
                  if (!mounted) return;
                  m.showSnackBar(const SnackBar(content: Text('Recarga local +50 aplicada')));
                },
                child: const Text('Local +50'),
              ),
              OutlinedButton(
                onPressed: () => _openLibelula(10),
                child: const Text('Libélula +10'),
              ),
              OutlinedButton(
                onPressed: () => _openLibelula(20),
                child: const Text('Libélula +20'),
              ),
              OutlinedButton(
                onPressed: () => _openLibelula(50),
                child: const Text('Libélula +50'),
              ),
            ],
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
