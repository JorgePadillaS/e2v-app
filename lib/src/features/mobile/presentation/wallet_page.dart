import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/ui/app_toast.dart';
import '../data/mobile_api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/wallet_refresh_provider.dart';
import 'package:dio/dio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../auth/presentation/profile_screen.dart';
import '../../auth/presentation/vehicles_screen.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key, required this.api, this.displayName});
  final MobileApi api;
  final String? displayName;

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> with WidgetsBindingObserver {
  // Safe Futures
  Future<Map<String, dynamic>>? _walletFuture;
  Future<Map<String, dynamic>>? _txFuture;

  bool _isRefreshing = false;
  final amountCtrl = TextEditingController(text: '50');
  final List<double> quickAmounts = const [50, 100, 150];
  double selectedAmount = 10;

  // Plugins (Safe Init)
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  int? _pendingTxId;

  @override
  void initState() {
    super.initState();
    _safeInit();
  }

  void _safeInit() {
    try {
      _initData();
      WidgetsBinding.instance.addObserver(this);
      Future.delayed(const Duration(milliseconds: 500), () => _safeInitDeepLinks());
    } catch (_) {}
  }

  void _safeInitDeepLinks() {
    try {
      if (!mounted) return;
      _appLinks = AppLinks();
      _linkSubscription = _appLinks?.uriLinkStream.listen((uri) {
        if (uri.scheme == 'e2vapp' && uri.host == 'payment-complete') {
          final txIdStr = uri.queryParameters['tx_id'];
          final txId = int.tryParse(txIdStr ?? '');
          if (txId != null) {
            _reload();
            _checkTransactionStatus(txId);
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    amountCtrl.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
      if (_pendingTxId != null) _checkTransactionStatus(_pendingTxId!);
    }
  }

  void _initData() {
    try {
      _walletFuture = widget.api.wallet();
      _txFuture = widget.api.walletTransactions();
    } catch (_) {}
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (showLoader && mounted) setState(() => _isRefreshing = true);
    setState(() => _initData());
    try {
      if (_walletFuture != null && _txFuture != null) {
        await Future.wait([_walletFuture!, _txFuture!]);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _checkTransactionStatus(int txId) async {
    try {
      final statusResp = await widget.api.libelulaStatus(txId);
      final status = (statusResp['status']?.toString() ?? 'PENDING').toUpperCase();
      final amount = double.tryParse(statusResp['amount']?.toString() ?? '0.0') ?? 0.0;
      if (status == 'COMPLETED') {
        _pendingTxId = null;
        if (mounted) {
          _showSuccessAlert(amount);
          _reload();
        }
      } else if (status == 'FAILED') {
        _pendingTxId = null;
        if (mounted) {
          showAppToast(context, 'Pago fallido.', type: AppToastType.error);
          _reload();
        }
      }
    } catch (_) {}
  }

  void _showSuccessAlert(double amount) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 10),
                Text('¡Recarga Exitosa!'),
              ],
            ),
            content: Text('Se han acreditado Bs ${amount.toStringAsFixed(2)} a tu saldo.', textAlign: TextAlign.center),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ENTENDIDO'))],
          ),
    );
  }

  void _showBillingDocumentRequiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Documento Requerido',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Completar Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }

  Future<void> _initiateCheckout() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (amount < 1.0) {
      showAppToast(context, 'Monto mínimo Bs 1.00', type: AppToastType.warning);
      return;
    }
    
    // Show loader for fetching vehicles
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    List<dynamic> vehicles = [];
    try {
      vehicles = await widget.api.getVehicles();
      if (mounted) Navigator.pop(context); // Close loader
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        showAppToast(context, 'Error al obtener vehículos: $e', type: AppToastType.error);
      }
      return;
    }
    
    final validVehicles = vehicles.where((v) => v['plate'] != null && v['plate'].toString().trim().isNotEmpty).toList();
    
    if (validVehicles.isEmpty) {
      // Show dialog asking to register a plate
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Registro de Placa Requerido'),
          content: const Text(
            'Para cumplir con Impuestos Nacionales, debes registrar la placa de tu vehículo antes de recargar saldo o realizar pagos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehiclesScreen()),
                );
              },
              child: const Text('Registrar Placa'),
            ),
          ],
        ),
      );
      return;
    }
    
    String? selectedPlate;
    if (validVehicles.length == 1) {
      selectedPlate = validVehicles.first['plate'].toString().trim();
    } else {
      selectedPlate = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Selecciona tu vehiculo'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: validVehicles.length,
              itemBuilder: (context, index) {
                final v = validVehicles[index];
                final brand = v['brand']?.toString() ?? '';
                final model = v['model']?.toString() ?? '';
                final plate = v['plate']?.toString() ?? '';
                
                return ListTile(
                  leading: const Icon(LucideIcons.car, color: Colors.blue),
                  title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$brand $model'),
                  onTap: () => Navigator.pop(dialogCtx, plate),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }
    
    if (selectedPlate == null) return; // User cancelled
    
    // Show loader for checkout
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final res = await widget.api.libelulaCheckout(amount, plate: selectedPlate);
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      
      final txId = int.tryParse(res['transaction_id']?.toString() ?? '');
      final url = res['payment_url']?.toString() ?? '';
      if (url.isEmpty) throw Exception('No se pudo generar la URL de pago.');
      _pendingTxId = txId;
      _reload();
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['status'] == 'billing_document_required') {
          _showBillingDocumentRequiredDialog(context, data['message'] ?? 'Se requiere registrar tu NIT/CI.');
          return;
        }
      }
      showAppToast(context, 'Error: $e', type: AppToastType.error);
    }
  }

  Future<void> _deletePending(int txId) async {
    try {
      await widget.api.deletePendingLibelula(txId);
      if (mounted) {
        showAppToast(context, 'Recarga pendiente eliminada.');
        _reload();
      }
    } catch (e) {
      if (mounted) showAppToast(context, 'Error al eliminar: $e', type: AppToastType.error);
    }
  }

  Future<void> _downloadHistory() async {
    try {
      final url = widget.api.walletHistoryDownloadUrl();
      debugPrint('Downloading history from: $url');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showAppToast(context, 'Error al descargar: $e', type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(walletRefreshProvider, (_, __) {
      _reload();
    });
    try {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () => _reload(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                title: const Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)),
                floating: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: _downloadHistory,
                    tooltip: 'Descargar Historial (PDF)',
                  ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => _reload(showLoader: true)),
                ],
              ),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _buildBalanceCard(theme))),
              SliverToBoxAdapter(child: _buildCardsSection(theme)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recargar Saldo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      //_buildQuickAmounts(theme),
                      //const SizedBox(height: 12),
                      _buildManualAmountField(theme),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initiateCheckout,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('IR A PAGAR (QR/TARJETA)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // TRANSACTIONS LOGIC
              _buildHistorySections(theme),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      );
    } catch (e) {
      return Scaffold(body: Center(child: Text('ERROR CRÍTICO: $e')));
    }
  }

  Widget _buildCardsSection(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _walletFuture,
      builder: (context, snapshot) {
        final tags = (snapshot.data?['tags'] as List?) ?? [];
        if (tags.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Mis Tarjetas Físicas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 168,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: tags.length,
                itemBuilder: (context, i) {
                  final tag = Map<String, dynamic>.from(tags[i] as Map);
                  final isActive = tag['is_active'] == true || tag['is_active'] == 1;
                  final tagBalance = double.tryParse(tag['balance']?.toString() ?? '0') ?? 0.0;

                  return Container(
                    width: 220,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isActive ? Colors.blue.shade200 : Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.credit_card, color: isActive ? theme.primaryColor : Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tag['name']?.toString() ?? 'Tarjeta E2V',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showRenameDialog(tag['id'], tag['name']?.toString() ?? ''),
                              icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        //const SizedBox(height: 2),
                        Text(
                          tag['tag_code']?.toString() ?? '000000',
                          style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade700, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Saldo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  'Bs ${tagBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'ACTIVA' : 'INACTIVA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showRenameDialog(int tagId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Identificar Tarjeta'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Nombre o Alias', hintText: 'Ej: Camioneta Jorge'),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(dialogContext);
                  final messenger = ScaffoldMessenger.of(dialogContext);
                  try {
                    await widget.api.updateTag(tagId, controller.text);
                    if (dialogContext.mounted) {
                      navigator.pop();
                      _reload();
                    }
                  } catch (e) {
                    if (dialogContext.mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('GUARDAR'),
              ),
            ],
          ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _walletFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          //return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12)));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            showAppToast(
              context,
              'Error de conexión al cargar el saldo. Por favor intente nuevamente en unos instantes.',
              type: AppToastType.error,
              duration: 5,
            );
          });
        }

        final data = snapshot.data ?? {};
        final balance = double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0;
        final appBalance = double.tryParse(data['app_balance']?.toString() ?? balance.toString()) ?? balance;
        final physicalBalance = double.tryParse(data['physical_balance']?.toString() ?? balance.toString()) ?? balance;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saldo Total', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bs ${balance.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo App',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Bs ${appBalance.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo Tarjetas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Bs ${physicalBalance.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /* Widget _buildQuickAmounts(ThemeData theme) {
    return Row(
      children:
          quickAmounts.map((amt) {
            final isSelected = selectedAmount == amt;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap:
                      () => setState(() {
                        selectedAmount = amt;
                        amountCtrl.text = amt.toStringAsFixed(0);
                      }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.primaryColor : Colors.white,
                      border: Border.all(color: isSelected ? theme.primaryColor : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${amt.toInt()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  } */

  Widget _buildManualAmountField(ThemeData theme) {
    return TextField(
      controller: amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => setState(() => selectedAmount = double.tryParse(v) ?? 0),
      decoration: InputDecoration(
        prefixText: 'Bs ',
        labelText: 'Monto',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildHistorySections(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _txFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          //return SliverToBoxAdapter(child: Center(child: Text('Fallo al cargar movimientos: ${snapshot.error}')));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            showAppToast(
              context,
              'Error de conexión al cargar movimientos. Por favor intente nuevamente en unos instantes.',
              type: AppToastType.error,
              duration: 5,
            );
          });
        }
        if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }

        final list = (snapshot.data?['data'] as List?) ?? [];
        if (list.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Text('Sin movimientos recientes', style: TextStyle(color: Colors.grey))),
          );
        }

        // 1. RECARGAS PENDIENTES
        final pendingRecharges =
            list.where((item) {
              final s = item['status']?.toString().toUpperCase() ?? '';
              final t = item['type']?.toString().toUpperCase() ?? '';
              return t == 'RECHARGE' && (s == 'PENDING' || s == 'PROCESSING' || s == '-' || s == '');
            }).toList();

        // 2. RECARGAS EXITOSAS
        final successfulRecharges =
            list.where((item) {
              final s = item['status']?.toString().toUpperCase() ?? '';
              final t = item['type']?.toString().toUpperCase() ?? '';
              return t == 'RECHARGE' && (s == 'COMPLETED' || s == 'SUCCESS');
            }).toList();

        // 3. DÉBITOS POR CARGA (Basado en el tipo 'CHARGE' de la DB)
        final energyDebits =
            list.where((item) {
              final t = item['type']?.toString().toUpperCase() ?? '';
              return t == 'CHARGE' || t == 'DEBIT' || t == 'CONSUMPTION';
            }).toList();

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // CARD 1: PENDIENTES
              if (pendingRecharges.isNotEmpty)
                _buildExpansionCard(
                  title: 'RECARGAS PENDIENTES',
                  subtitle: '${pendingRecharges.length} pendientes',
                  icon: Icons.timer_outlined,
                  iconColor: Colors.orange,
                  items: pendingRecharges,
                  itemBuilder: (item) => _buildPendingItem(theme, item),
                  isExpanded: true,
                ),

              const SizedBox(height: 12),

              // CARD 2: EXITOSAS
              _buildExpansionCard(
                title: 'RECARGAS EXITOSAS',
                subtitle: 'Historial de depósitos',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: Colors.green,
                items: successfulRecharges,
                itemBuilder: (item) => _buildSuccessItem(theme, item),
              ),

              const SizedBox(height: 12),

              // CARD 3: DÉBITOS POR CARGA
              _buildExpansionCard(
                title: 'DÉBITOS POR CARGA',
                subtitle: 'Consumos de energía',
                icon: Icons.ev_station_outlined,
                iconColor: Colors.red,
                items: energyDebits,
                itemBuilder: (item) => _buildDebitItem(theme, item),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildExpansionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List items,
    required Widget Function(dynamic) itemBuilder,
    bool isExpanded = false,
  }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        children:
            items.isEmpty
                ? [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay registros en esta sección', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ]
                : items.map((item) => itemBuilder(item)).toList(),
      ),
    );
  }

  Widget _buildPendingItem(ThemeData theme, dynamic item) {
    try {
      final tx = Map<String, dynamic>.from(item as Map);
      final txId = int.tryParse(tx['id']?.toString() ?? '0') ?? 0;
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
      final url = tx['payment_url']?.toString() ?? '';

      return Dismissible(
        key: Key('pending_${tx['id']}'),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            // Right
            if (url.isNotEmpty) launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
            return false; // Don't remove from list yet
          } else {
            // Left
            final confirm = await _showConfirmDelete();
            if (confirm) {
              await _deletePending(txId);
              return true;
            }
            return false;
          }
        },
        background: Container(
          alignment: Alignment.centerLeft,
          color: Colors.blue,
          padding: const EdgeInsets.only(left: 20),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, color: Colors.white),
              Text('REINTENTAR', style: TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          color: Colors.red,
          padding: const EdgeInsets.only(right: 20),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: Colors.white),
              Text('ELIMINAR', style: TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.orange.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade200)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.timer_outlined, color: Colors.white)),
            title: const Text(
              'Recarga Pendiente',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('ID: ${tx['id']}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              'Bs ${amount.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange),
            ),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSuccessItem(ThemeData theme, dynamic item) {
    try {
      final tx = Map<String, dynamic>.from(item as Map);
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
      final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
      final invoiceUrl = tx['invoice_url']?.toString();

      return Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.add, color: Colors.green),
            ),
            title: Text(
              tx['description']?.toString() ?? 'Recarga de Saldo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: SizedBox(
              width: invoiceUrl != null && invoiceUrl.isNotEmpty && invoiceUrl.contains('http') ? 120 : 76,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Bs ${amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                    ),
                  ),
                  if (invoiceUrl != null && invoiceUrl.isNotEmpty && invoiceUrl.contains('http'))
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Color(0xFF0076D6), size: 20),
                      onPressed: () => launchUrl(Uri.parse(invoiceUrl), mode: LaunchMode.externalApplication),
                      tooltip: 'Ver Factura',
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDebitItem(ThemeData theme, dynamic item) {
    try {
      final tx = Map<String, dynamic>.from(item as Map);
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
      final date = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
      final invoiceUrl = tx['invoice_url']?.toString();

      return Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              child: const Icon(Icons.remove, color: Colors.red),
            ),
            title: Text(
              tx['description']?.toString() ?? 'Consumo de Energía',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: SizedBox(
              width: invoiceUrl != null && invoiceUrl.isNotEmpty && invoiceUrl.contains('http') ? 120 : 76,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Bs ${amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                    ),
                  ),
                  if (invoiceUrl != null && invoiceUrl.isNotEmpty && invoiceUrl.contains('http'))
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Color(0xFF0076D6), size: 20),
                      onPressed: () => launchUrl(Uri.parse(invoiceUrl), mode: LaunchMode.externalApplication),
                      tooltip: 'Ver Factura',
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<bool> _showConfirmDelete() async {
    return await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Eliminar Pendiente'),
                content: const Text('¿Estás seguro de que deseas eliminar esta recarga pendiente?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('ELIMINAR', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
        ) ??
        false;
  }
}
