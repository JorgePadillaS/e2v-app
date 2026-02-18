import 'dart:async';

import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.api, this.displayName});
  final MobileApi api;
  final String? displayName;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _wallet;
  late Future<Map<String, dynamic>> _tx;
  final amountCtrl = TextEditingController(text: '10');
  final List<double> quickAmounts = const [10, 30, 60, 90, 150];
  double selectedAmount = 10;
  int? _lastCompletedTxId;

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

  double _manualAmount() {
    return double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  Future<void> _confirmAndOpenLibelula() async {
    final amount = _manualAmount();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero indica un monto de recarga')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar recarga'),
        content: Text('¿Deseas iniciar una recarga por Bs ${amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );

    if (ok != true) return;
    await _openLibelula(amount);
  }

  Future<void> _openLibelula(double amount) async {
    final m = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final res = await widget.api.libelulaCheckout(amount);
      if (!mounted) return;

      final txId = (res['transaction_id'] as num?)?.toInt();
      final url = res['payment_url']?.toString() ?? '';
      final qr = res['qr_image']?.toString() ?? '';

      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      final status = ValueNotifier<String>('PENDING');
      Timer? timer;

      Future<void> checkStatus() async {
        if (txId == null) return;
        try {
          final s = await widget.api.libelulaStatus(txId);
          final st = (s['status']?.toString() ?? 'PENDING').toUpperCase();
          status.value = st;

          if (st == 'COMPLETED') {
            timer?.cancel();
            if (!mounted) return;
            setState(() => _lastCompletedTxId = txId);
            navigator.maybePop();
            await _reload();
            m.showSnackBar(const SnackBar(content: Text('✅ Pago confirmado. Crédito aplicado.')));
          } else if (st == 'FAILED') {
            timer?.cancel();
            if (!mounted) return;
            m.showSnackBar(const SnackBar(content: Text('❌ Pago fallido o rechazado.')));
          }
        } catch (_) {}
      }

      timer = Timer.periodic(const Duration(seconds: 4), (_) => checkStatus());

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text('Recarga Bs ${amount.toStringAsFixed(2)}'),
          content: SingleChildScrollView(
            child: Column(
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
                  const SizedBox(height: 12),
                ],
                const Text('Estado:'),
                const SizedBox(height: 6),
                ValueListenableBuilder<String>(
                  valueListenable: status,
                  builder: (_, st, __) => Row(
                    children: [
                      if (st == 'PENDING') ...[
                        const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                      ],
                      Text(st),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(url),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: url));
                messenger.showSnackBar(const SnackBar(content: Text('Link copiado')));
              },
              child: const Text('Copiar link'),
            ),
            FilledButton(
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Abrir pago'),
            ),
            OutlinedButton(onPressed: checkStatus, child: const Text('Verificar ahora')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );

      timer.cancel();
      status.dispose();
    } catch (e) {
      if (!mounted) return;
      m.showSnackBar(SnackBar(content: Text('Error Libélula: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Recarga tu Crédito', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          const Text('Confirma los datos de tu recarga', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(value: 0.5, minHeight: 8),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF34D6C8), Color(0xFF3E5BE0), Color(0xFF5A2EA9)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TARJETA VIRTUAL', style: TextStyle(fontSize: 21, color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('TARJETA VIRTUAL · E2V', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 22),
                FutureBuilder<Map<String, dynamic>>(
                  future: _wallet,
                  builder: (_, snap) {
                    final amount = _toDouble(snap.data?['balance']);
                    return Text('Bs ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white));
                  },
                ),
                const SizedBox(height: 14),
                Text(widget.displayName ?? 'Cliente E2V', style: const TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('Elige el monto de tu recarga', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: quickAmounts
                        .map(
                          (a) => GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedAmount = a;
                                amountCtrl.text = a.toStringAsFixed(0);
                              });
                            },
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: selectedAmount == a ? Colors.tealAccent : const Color(0xFF595591),
                                  width: 2,
                                ),
                              ),
                              child: Center(child: Text('Bs ${a.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto manual', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Datos para la Factura', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(height: 10),
                  const Text('Documento: 10668541', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Razon Social: ${widget.displayName ?? 'Cliente E2V'}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () {}, child: const Text('Modificar Datos de Facturación')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    amountCtrl.text = selectedAmount.toStringAsFixed(0);
                  },
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _confirmAndOpenLibelula,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Recargas Pendientes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _tx,
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final rows = ((snap.data!['data'] as List?) ?? const [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .where((e) => (e['status']?.toString().toUpperCase() ?? '') == 'PENDING')
                  .toList();
              if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay pendientes')));
              return Column(
                children: rows
                    .map((it) => Card(
                          child: ListTile(
                            title: Text('RECARGA ${it['amount']}'),
                            subtitle: Text(it['created_at']?.toString() ?? ''),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text('Últimas Recargas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _tx,
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final rows = ((snap.data!['data'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
              if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Sin recargas aún')));
              return Column(
                children: rows
                    .take(5)
                    .map((it) {
                      final txId = (it['id'] as num?)?.toInt();
                      final isRecentPaid = _lastCompletedTxId != null && txId == _lastCompletedTxId;
                      return Card(
                        color: isRecentPaid ? Colors.green.withValues(alpha: 0.18) : null,
                        child: ListTile(
                          title: Text('RECARGA ${it['amount']}'),
                          subtitle: Text(it['created_at']?.toString() ?? ''),
                          trailing: Text((it['status'] ?? '-').toString()),
                        ),
                      );
                    })
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
