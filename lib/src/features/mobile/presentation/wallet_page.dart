import 'dart:async';

import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';
import 'package:e2v_app/src/features/mobile/presentation/billing_flow_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/payment_webview_modal.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.api,
    this.displayName,
    this.initialBillingDocument,
    this.initialBillingDocType,
    this.initialBillingComplement,
    this.initialBillingRazonSocial,
  });
  final MobileApi api;
  final String? displayName;
  final String? initialBillingDocument;
  final String? initialBillingDocType;
  final String? initialBillingComplement;
  final String? initialBillingRazonSocial;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _wallet;
  late Future<Map<String, dynamic>> _tx;
  bool _isLoadingData = true;
  final amountCtrl = TextEditingController(text: '10');
  final razonSocialCtrl = TextEditingController();
  final documentoCtrl = TextEditingController(text: '');
  final complementoCtrl = TextEditingController(text: '');
  final List<double> quickAmounts = const [10, 30, 60, 90, 150];
  double selectedAmount = 10;
  int? _lastCompletedTxId;
  String billingDocType = 'NIT';

  @override
  void initState() {
    super.initState();
    razonSocialCtrl.text = widget.initialBillingRazonSocial?.isNotEmpty == true
        ? widget.initialBillingRazonSocial!
        : (widget.displayName ?? '');
    documentoCtrl.text = widget.initialBillingDocument ?? '';
    complementoCtrl.text = widget.initialBillingComplement ?? '';
    billingDocType = (widget.initialBillingDocType == 'CI' || widget.initialBillingDocType == 'NIT')
        ? widget.initialBillingDocType!
        : 'NIT';
    _wallet = widget.api.wallet();
    _tx = widget.api.walletTransactions();
    _reload(showLoader: true);
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    razonSocialCtrl.dispose();
    documentoCtrl.dispose();
    complementoCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _isLoadingData = true);
    }

    setState(() {
      _wallet = widget.api.wallet();
      _tx = widget.api.walletTransactions();
    });

    try {
      await Future.wait([_wallet, _tx]);
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
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

  String _txCodeOf(Map<String, dynamic> it) {
    final ext = (it['external_payment_id'] ?? '').toString();
    if (ext.isNotEmpty && ext != 'null') return ext;
    final ref = (it['reference_id'] ?? it['reference'] ?? '').toString();
    return ref;
  }

  String _invoiceViewUrl(String rawUrl) {
    final u = rawUrl.trim();
    if (u.isEmpty) return '';
    final lower = u.toLowerCase();
    if (lower.endsWith('.pdf') || lower.contains('factura') || lower.contains('invoice')) {
      return 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(u)}';
    }
    return u;
  }

  String _paymentUrlOf(Map<String, dynamic> it) {
    final raw = it['metadata'];
    if (raw is Map) {
      final reg = raw['register_response'];
      if (reg is Map && reg['url_pasarela_pagos'] != null) return reg['url_pasarela_pagos'].toString();
      if (raw['url_pasarela_pagos'] != null) return raw['url_pasarela_pagos'].toString();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final sub = raw.substring(raw.indexOf('url_pasarela_pagos'));
        final q = RegExp(r'url_pasarela_pagos"\s*:\s*"([^"]+)"').firstMatch(sub);
        if (q != null) return q.group(1)!.replaceAll('\\/', '/');
      } catch (_) {}
    }
    return '';
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

  Future<void> _confirmAndOpenLibelula({VoidCallback? onSuccess}) async {
    final amount = _manualAmount();
    if (amount <= 0) {
      showAppToast(context, 'Primero indica un monto de recarga', type: AppToastType.warning);
      return;
    }
    if (amount < 1) {
      showAppToast(context, 'Monto mínimo para Libélula: Bs 1.00', type: AppToastType.warning);
      return;
    }

    await _openLibelula(amount, onSuccess: onSuccess);
  }

  Future<void> _openLibelula(double amount, {VoidCallback? onSuccess}) async {
    // toast handled via showAppToast
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final res = await widget.api.libelulaCheckout(
        amount,
        razonSocial: razonSocialCtrl.text.trim(),
        documento: documentoCtrl.text.trim(),
        complemento: complementoCtrl.text.trim(),
        docType: billingDocType,
      );
      if (!mounted) return;

      final txId = (res['transaction_id'] as num?)?.toInt();
      final url = res['payment_url']?.toString() ?? '';

      if (url.isEmpty) {
        showAppToast(context, 'No llegó URL de pago de Libélula', type: AppToastType.error);
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
            showAppToast(context, 'Recarga exitosa: Bs ${amount.toStringAsFixed(2)}', type: AppToastType.success);
            await _reload();
            onSuccess?.call();
          } else if (st == 'FAILED') {
            timer?.cancel();
            if (!mounted) return;
            navigator.maybePop();
            showAppToast(context, 'Pago fallido o rechazado.', type: AppToastType.error);
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
      showAppToast(context, 'Error Libélula: $e', type: AppToastType.error);
    }
  }

  Future<void> _openSectionModal(String title, Widget Function(StateSetter modalSetState) childBuilder) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, controller) => StatefulBuilder(
          builder: (context, modalSetState) => Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: controller,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                childBuilder(modalSetState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountRow({VoidCallback? refreshModal}) {
    return Row(
      children: quickAmounts
          .map((a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAmount = a;
                        amountCtrl.text = a.toStringAsFixed(0);
                      });
                      refreshModal?.call();
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selectedAmount == a ? Colors.teal.withValues(alpha: 0.24) : null,
                        border: Border.all(
                          color: selectedAmount == a ? Colors.tealAccent : const Color(0xFF595591),
                          width: selectedAmount == a ? 2.6 : 1.6,
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Bs ${a.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _actionCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.keyboard_arrow_up),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget rechargeContent(StateSetter modalSetState) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Elige el monto de tu recarga', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _amountRow(refreshModal: () => modalSetState(() {})),
        const SizedBox(height: 12),
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto manual', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        const Text('Datos para la Factura', style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo: $billingDocType', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text('Documento: ${documentoCtrl.text.isEmpty ? '-' : documentoCtrl.text}', style: const TextStyle(fontSize: 16)),
              if (billingDocType == 'CI') ...[
                const SizedBox(height: 6),
                Text('Complemento: ${complementoCtrl.text.isEmpty ? '-' : complementoCtrl.text}', style: const TextStyle(fontSize: 16)),
              ],
              const SizedBox(height: 6),
              Text('Razón Social: ${razonSocialCtrl.text.isEmpty ? '-' : razonSocialCtrl.text}', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<Map<String, String>>(
                MaterialPageRoute(
                  builder: (_) => BillingFlowPage(
                    initialType: billingDocType,
                    initialDocumento: documentoCtrl.text,
                    initialComplemento: complementoCtrl.text,
                    initialRazonSocial: razonSocialCtrl.text,
                  ),
                ),
              );
              if (result != null && mounted) {
                setState(() {
                  billingDocType = result['doc_type'] ?? billingDocType;
                  documentoCtrl.text = result['documento'] ?? documentoCtrl.text;
                  complementoCtrl.text = result['complemento'] ?? complementoCtrl.text;
                  razonSocialCtrl.text = result['razon_social'] ?? razonSocialCtrl.text;
                });
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Modificar'),
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
              child: Builder(
                builder: (modalContext) => FilledButton(
                  onPressed: () => _confirmAndOpenLibelula(
                    onSuccess: () {
                      if (Navigator.of(modalContext).canPop()) {
                        Navigator.of(modalContext).pop();
                      }
                    },
                  ),
                  child: const Text('Recargar'),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    Widget pendingContent(StateSetter _) => FutureBuilder<Map<String, dynamic>>(
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
                final txId = (it['id'] as num?)?.toInt();
                final url = _paymentUrlOf(it);

                return Dismissible(
                  key: ValueKey('pending_modal_${it['id']}'),
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.teal,
                    child: const Row(
                      children: [Icon(Icons.open_in_new, color: Colors.white), SizedBox(width: 8), Text('Continuar pago', style: TextStyle(color: Colors.white))],
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.red,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [Text('Eliminar', style: TextStyle(color: Colors.white)), SizedBox(width: 8), Icon(Icons.delete, color: Colors.white)],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      if (url.isEmpty) {
                        showAppToast(context, 'No hay URL para retomar pago', type: AppToastType.warning);
                        return false;
                      }
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PaymentWebViewModal(url: url),
                      );
                      return false;
                    }

                    if (txId == null) return false;
                    try {
                      await widget.api.deletePendingLibelula(txId);
                      if (!context.mounted) return false;
                      showAppToast(context, 'Transacción eliminada', type: AppToastType.success);
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      await _reload(showLoader: true);
                    } catch (e) {
                      if (!context.mounted) return false;
                      showAppToast(context, 'No se pudo eliminar: $e', type: AppToastType.error);
                    }
                    return false;
                  },
                  child: Card(
                    child: ListTile(
                      title: Text('RECARGA ${_toDouble(it['amount']).toStringAsFixed(2)}'),
                      subtitle: Text('Código: ${_txCodeOf(it).isEmpty ? '-' : _txCodeOf(it)}'),
                      trailing: Chip(
                        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        backgroundColor: color,
                      ),
                    ),
                  ),
                );
              })
              .toList(),
        );
      },
    );

    Widget recargasContent(StateSetter _) => FutureBuilder<Map<String, dynamic>>(
      future: _tx,
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final rows = ((snap.data!['data'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).take(8).toList();
        if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Sin recargas aún')));
        return Column(
          children: rows
              .map((it) {
                final st = _statusOf(it);
                final (color, label) = _statusStyle(st);
                final invoiceUrlRaw = (it['invoice_url'] ?? '').toString();
                return Card(
                  child: ListTile(
                    title: Text('RECARGA ${_toDouble(it['amount']).toStringAsFixed(2)}'),
                    subtitle: Text('Código: ${_txCodeOf(it).isEmpty ? '-' : _txCodeOf(it)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (invoiceUrlRaw.isNotEmpty)
                          IconButton(
                            tooltip: 'Ver factura',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () async {
                              final invoiceUrl = _invoiceViewUrl(invoiceUrlRaw);
                              if (invoiceUrl.isEmpty) return;
                              await showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => PaymentWebViewModal(
                                  url: invoiceUrl,
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
    );

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _reload(showLoader: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Recarga tu Crédito', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
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
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _wallet,
                  builder: (_, snap) {
                    final amount = _toDouble(snap.data?['balance']);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TARJETA VIRTUAL · E2V', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        Text('Bs ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _actionCard(
                title: 'Recargar',
                subtitle: 'Monto + datos de factura',
                icon: Icons.account_balance_wallet,
                onTap: () => _openSectionModal('Recargar crédito', rechargeContent),
              ),
              _actionCard(
                title: 'Pendientes',
                subtitle: 'Pagos en proceso o por reintentar',
                icon: Icons.pending_actions,
                onTap: () => _openSectionModal('Recargas pendientes', pendingContent),
              ),
              _actionCard(
                title: 'Mis recargas',
                subtitle: 'Historial reciente',
                icon: Icons.receipt_long,
                onTap: () => _openSectionModal('Últimas recargas', recargasContent),
              ),
            ],
          ),
        ),
        if (_isLoadingData)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
