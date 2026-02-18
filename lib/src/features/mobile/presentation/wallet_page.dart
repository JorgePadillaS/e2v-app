import 'dart:async';

import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';
// removed services import
import 'package:e2v_app/src/features/mobile/presentation/payment_webview_modal.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.api,
    this.displayName,
    this.initialBillingDocument,
    this.initialBillingComplement,
    this.initialBillingRazonSocial,
  });
  final MobileApi api;
  final String? displayName;
  final String? initialBillingDocument;
  final String? initialBillingComplement;
  final String? initialBillingRazonSocial;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _wallet;
  late Future<Map<String, dynamic>> _tx;
  final amountCtrl = TextEditingController(text: '10');
  final razonSocialCtrl = TextEditingController();
  final documentoCtrl = TextEditingController(text: '');
  final complementoCtrl = TextEditingController(text: '');
  final List<double> quickAmounts = const [10, 30, 60, 90, 150];
  double selectedAmount = 10;
  int? _lastCompletedTxId;
  bool isEditingBilling = false;

  @override
  void initState() {
    super.initState();
    razonSocialCtrl.text = widget.initialBillingRazonSocial?.isNotEmpty == true
        ? widget.initialBillingRazonSocial!
        : (widget.displayName ?? '');
    documentoCtrl.text = widget.initialBillingDocument ?? '';
    complementoCtrl.text = widget.initialBillingComplement ?? '';
    isEditingBilling = documentoCtrl.text.isEmpty || razonSocialCtrl.text.isEmpty;
    _wallet = widget.api.wallet();
    _tx = widget.api.walletTransactions();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    razonSocialCtrl.dispose();
    documentoCtrl.dispose();
    complementoCtrl.dispose();
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

  String _statusOf(Map<String, dynamic> it) {
    final raw = (it['status'] ?? '').toString().toUpperCase().trim();
    final txId = (it['id'] as num?)?.toInt();
    if (raw.isEmpty || raw == '-') {
      if (_lastCompletedTxId != null && txId == _lastCompletedTxId) return 'COMPLETED';
      return 'PENDING';
    }
    return raw;
  }

  (Color, String) _statusStyle(String status) {
    if (status == 'COMPLETED' || status == 'SUCCESS' || status == 'PAID' || status == 'PAGADO') {
      return (Colors.green, 'PROCESADO');
    }
    if (status == 'FAILED' || status == 'REJECTED' || status == 'ERROR') {
      return (Colors.red, 'FALLIDO');
    }
    return (Colors.amber, 'EN PROCESO');
  }

  Future<void> _confirmAndOpenLibelula() async {
    final amount = _manualAmount();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero indica un monto de recarga')));
      return;
    }

    await _openLibelula(amount);
  }

  Future<void> _openLibelula(double amount) async {
    final m = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final res = await widget.api.libelulaCheckout(
        amount,
        razonSocial: razonSocialCtrl.text.trim(),
        documento: documentoCtrl.text.trim(),
        complemento: complementoCtrl.text.trim(),
      );
      if (!mounted) return;

      final txId = (res['transaction_id'] as num?)?.toInt();
      final url = res['payment_url']?.toString() ?? '';

      if (url.isEmpty) {
        m.showSnackBar(const SnackBar(content: Text('No llegó URL de pago de Libélula')));
        return;
      }

      Timer? timer;
      Future<void> checkStatus() async {
        if (txId == null) return;
        try {
          final s = await widget.api.libelulaStatus(txId);
          final st = (s['status']?.toString() ?? 'PENDING').toUpperCase();

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
            navigator.maybePop();
            m.showSnackBar(const SnackBar(content: Text('❌ Pago fallido o rechazado.')));
          }
        } catch (_) {}
      }

      timer = Timer.periodic(const Duration(seconds: 4), (_) => checkStatus());
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentWebViewModal(url: url),
      );

      timer.cancel();
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Datos para la Factura', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(height: 10),
                  if (!isEditingBilling) ...[
                    Text('Documento: ${documentoCtrl.text.isEmpty ? '-' : documentoCtrl.text}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Complemento: ${complementoCtrl.text.isEmpty ? '-' : complementoCtrl.text}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Razón Social: ${razonSocialCtrl.text.isEmpty ? '-' : razonSocialCtrl.text}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => isEditingBilling = true),
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar datos'),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: documentoCtrl,
                      decoration: const InputDecoration(labelText: 'Documento (NIT/CI)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: complementoCtrl,
                      decoration: const InputDecoration(labelText: 'Complemento (opcional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: razonSocialCtrl,
                      decoration: const InputDecoration(labelText: 'Razón social', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => isEditingBilling = false),
                          child: const Text('Listo'),
                        ),
                      ],
                    )
                  ],
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
                  .where((e) {
                    final st = _statusOf(e);
                    return !(st == 'COMPLETED' || st == 'SUCCESS' || st == 'PAID' || st == 'PAGADO');
                  })
                  .toList();
              if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay pendientes')));
              return Column(
                children: rows
                    .map((it) {
                      final st = _statusOf(it);
                      final (color, label) = _statusStyle(st);
                      return Card(
                        child: ListTile(
                          title: Text('RECARGA ${_toDouble(it['amount']).toStringAsFixed(2)}'),
                          subtitle: Text(it['created_at']?.toString().replaceAll('T', ' ').replaceAll('.000000Z', '') ?? ''),
                          trailing: Chip(
                            label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            backgroundColor: color,
                          ),
                        ),
                      );
                    })
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
                      final st = _statusOf(it);
                      final (color, label) = _statusStyle(st);
                      final isRecentPaid = _lastCompletedTxId != null && txId == _lastCompletedTxId;
                      return Card(
                        color: isRecentPaid ? Colors.green.withValues(alpha: 0.18) : null,
                        child: ListTile(
                          title: Text('RECARGA ${_toDouble(it['amount']).toStringAsFixed(2)}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it['created_at']?.toString().replaceAll('T', ' ').replaceAll('.000000Z', '') ?? ''),
                              if ((it['invoice_number'] ?? '').toString().isNotEmpty)
                                Text('Factura: ${it['invoice_number']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((it['invoice_url'] ?? '').toString().isNotEmpty)
                                IconButton(
                                  tooltip: 'Ver factura',
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () async {
                                    await showDialog(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (_) => PaymentWebViewModal(
                                        url: it['invoice_url'].toString(),
                                        title: 'Factura',
                                      ),
                                    );
                                  },
                                ),
                              Chip(
                                label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                backgroundColor: color,
                              ),
                            ],
                          ),
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
