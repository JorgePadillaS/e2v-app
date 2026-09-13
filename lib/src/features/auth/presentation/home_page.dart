import '../../../features/mobile/presentation/notifications_page.dart';
import '../../../core/ui/maxvolt_theme.dart';
import 'maxvolt_account_page.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/mobile/application/active_session_notifier.dart';
import '../../../features/mobile/application/wallet_refresh_provider.dart';
import '../../../features/mobile/data/mobile_api.dart';
import '../../../features/mobile/presentation/nfc_page.dart';
import '../../../features/mobile/presentation/sessions_page.dart';
import '../../../features/mobile/presentation/map/screens/charging_map_screen.dart';
import '../../../features/mobile/presentation/wallet_page.dart';
import 'vehicles_screen.dart';
import '../../../features/mobile/application/notification_notifier.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/config/branding_provider.dart';

import 'package:dio/dio.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int index = 0;
  late final List<Widget> _pages;
  late final MobileApi api;
  bool _hasCheckedNewUser = false;
  bool _hasCheckedBranding = false;
  late Future<Map<String, dynamic>> _balance;

  @override
  void initState() {
    super.initState();
    final user = Map<String, dynamic>.from(widget.data['user'] as Map);
    final token = widget.data['token']?.toString() ?? '';
    api = MobileApi(token);
    _balance = api.wallet();

    final assignedTag = (widget.data['rfid_tag'] is Map)
        ? (widget.data['rfid_tag']['tag_code']?.toString() ?? '')
        : '';

    _pages = [
      ChargingMapScreen(api: api),
      NfcPage(assignedTag: assignedTag, api: api),
      SessionsPage(api: api, onActiveSession: () => setState(() => index = 1)),
    ];

    // Initial fetch and start polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).startPolling(api);
      ref.read(activeSessionProvider.notifier).startPolling(api);
      _setupFirebaseMessaging();
      _checkBranding();
      _checkNewUserOnboarding();
    });
  }

  void _checkNewUserOnboarding() {
    if (_hasCheckedNewUser) return;
    _hasCheckedNewUser = true;

    final isNewUser = widget.data['is_new_user'] == true;
    if (isNewUser && mounted) {
      final user = widget.data['user'] as Map? ?? {};
      final name = user['name']?.toString() ?? '';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('¡Bienvenido, $name!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car, color: Color(0xFF03624C), size: 60),
              SizedBox(height: 16),
              Text(
                'Tu cuenta ha sido creada exitosamente. Para cumplir con impuestos y poder iniciar cargas, registra tu placa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
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
    }
  }

  void _checkBranding() {
    if (!mounted ||
        _hasCheckedBranding ||
        ref.read(brandingProvider).value == null)
      return;
    _hasCheckedBranding = true;
    _checkPolicies();
    _checkPromotions();
  }

  void _checkPolicies() async {
    final branding = ref.read(brandingProvider).value;
    if (branding == null) return;

    if (branding.policies.nitRequirementPolicy == 'required') {
      final authData = ref.read(authControllerProvider).value;
      final user = authData?['user'] as Map? ?? {};
      final nit = user['billing_document']?.toString() ?? '';

      if (nit.isEmpty && mounted) {
        _showMandatoryBillingDialog();
      }
    }
  }

  void _showMandatoryBillingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MandatoryBillingForm(
        onComplete: () {
          ref.read(brandingProvider.notifier).refresh();
        },
      ),
    );
  }

  void _checkPromotions() async {
    final branding = ref.read(brandingProvider).value;
    if (branding == null) return;

    final alerts = branding.promotions.where((p) => p.type == 'alert').toList();
    if (alerts.isEmpty) return;

    final token = widget.data['token']?.toString();

    for (final promo in alerts) {
      if (!mounted) break;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (promo.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    promo.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      promo.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      promo.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );

      // Track as seen
      if (token != null) {
        try {
          await ref.read(brandingApiProvider).trackSeen(token, promo.id);
        } catch (_) {}
      }
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Request permissions (important for iOS and Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get token and send to backend
      final token = await messaging.getToken();
      if (token != null) {
        try {
          await api.updateFcmToken(token);
        } catch (_) {}
      }

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Refresh notifications poll if we get a message
        ref.read(notificationProvider.notifier).poll(api);

        if (message.notification != null && mounted) {
          final data = message.data;
          final type = data['type']?.toString();

          // Show high-priority dialog for failed charges
          if (type == 'CHARGING_FAILED') {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    const Text('Falla en la carga'),
                  ],
                ),
                content: Text(
                  message.notification!.body ?? 'No se pudo iniciar la carga.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      'ENTENDIDO',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Show standard snackbar for other notifications
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.notification!.title ?? 'Nueva notificación',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(message.notification!.body ?? ''),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Ver',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsPage(api: api),
                    ),
                  ),
                ),
              ),
            );
          }
        }
      });

      // Handle message click when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NotificationsPage(api: api)),
        );
      });
    }
  }

  @override
  void dispose() {
    ref.read(notificationProvider.notifier).stopPolling();
    ref.read(activeSessionProvider.notifier).stopPolling();
    super.dispose();
  }

  Future<void> _openWallet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WalletPage(
          api: api,
          displayName: (widget.data['user'] as Map?)?['name']?.toString(),
        ),
      ),
    );
    if (mounted) {
      setState(() => _balance = api.wallet());
      ref.read(walletRefreshProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brandingProvider);
    ref.listen(brandingProvider, (previous, next) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkBranding());
      }
    });
    final session = ref.watch(activeSessionProvider).value;
    ref.listen(activeSessionProvider, (previous, next) {
      if (previous?.value != null &&
          next.asData?.value == null &&
          next.hasValue) {
        setState(() => _balance = api.wallet());
      }
    });
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MaxVolt.forest,
        foregroundColor: MaxVolt.paper,
        titleSpacing: 12,
        title: const MaxVoltLogo(width: 112),
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: _balance,
            builder: (context, snapshot) {
              final value = double.tryParse(
                snapshot.data?['app_balance']?.toString() ?? '',
              );
              return TextButton.icon(
                onPressed: _openWallet,
                style: TextButton.styleFrom(
                  foregroundColor: MaxVolt.paper,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                ),
                label: Text(
                  value == null ? 'Saldo' : 'Bs ${value.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Perfil y ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    MaxVoltAccountPage(api: api, openWallet: _openWallet),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (session != null && index != 1)
            Material(
              color: MaxVolt.forest,
              child: InkWell(
                onTap: () => setState(() => index = 1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: MaxVolt.lime, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tu sesión de carga',
                          style: TextStyle(color: MaxVolt.paper),
                        ),
                      ),
                      Text(
                        'Ver sesión →',
                        style: TextStyle(color: MaxVolt.paper),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  TickerMode(enabled: i == index, child: _pages[i]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              _destination(0, Icons.map_outlined, 'Mapa'),
              _destination(1, Icons.qr_code_scanner, 'Cargar'),
              _destination(2, Icons.history, 'Historial'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destination(int destination, IconData icon, String label) {
    final selected = index == destination;
    final charge = destination == 1;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          selected: selected,
          child: Material(
            color: charge
                ? MaxVolt.lime
                : selected
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => index = destination);
                if (destination != 0)
                  ref.read(activeSessionProvider.notifier).refresh();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: charge ? 16 : 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: charge ? 28 : 23,
                      color: charge
                          ? MaxVolt.night
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: charge
                            ? MaxVolt.night
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MandatoryBillingForm extends ConsumerStatefulWidget {
  const _MandatoryBillingForm({required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<_MandatoryBillingForm> createState() =>
      _MandatoryBillingFormState();
}

class _MandatoryBillingFormState extends ConsumerState<_MandatoryBillingForm> {
  final _formKey = GlobalKey<FormState>();
  final _nitCtrl = TextEditingController();
  final _rsCtrl = TextEditingController();
  String _docType = 'NIT';
  bool _loading = false;

  @override
  void dispose() {
    _nitCtrl.dispose();
    _rsCtrl.dispose();
    super.dispose();
  }

  String? _errorMessage;

  bool _isNitValid = false;
  bool _isValidating = false;
  String? _nitError;

  Future<void> _validateNit(String value) async {
    if (value.length < 5) {
      setState(() {
        _isNitValid = false;
        _nitError = 'El NIT/CI debe tener al menos 5 dígitos';
      });
      return;
    }

    setState(() => _isValidating = true);
    try {
      final available = await ref
          .read(authControllerProvider.notifier)
          .validateField('billing_document', value);
      if (mounted) {
        setState(() {
          _isNitValid = available;
          _nitError = available ? null : 'Este NIT/CI ya está registrado';
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_isNitValid) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'billing_document': _nitCtrl.text,
        'billing_razon_social': _rsCtrl.text,
        'billing_doc_type': _docType,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();

        // SHOW WELCOME DIALOG
        final authData = ref.read(authControllerProvider).value;
        final name = authData?['user']?['name'] ?? 'Usuario';

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text('¡Bienvenido, $name!'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 16),
                Text(
                  'Tus datos han sido registrados correctamente. Ya puedes empezar a utilizar la aplicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Comenzar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (e is DioException && e.response != null) {
          final data = e.response!.data;
          if (data is Map) {
            message = data['message'] ?? message;
            if (data['errors'] != null) {
              message += ": ${data['errors'].toString()}";
            }
          } else {
            message = e.response!.data.toString();
          }
        }
        setState(() => _errorMessage = message.replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text(
          'Datos de Facturación Requeridos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Para continuar utilizando la aplicación, debe registrar sus datos según la normativa SIAT.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _docType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Documento',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                    DropdownMenuItem(
                      value: 'CI',
                      child: Text('Cédula de Identidad'),
                    ),
                    DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                  ],
                  onChanged: (v) => setState(() => _docType = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _docType == 'NIT'
                        ? 'Número de NIT'
                        : 'Cédula de Identidad',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _nitError,
                    suffixIcon: _isValidating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_isNitValid
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null),
                  ),
                  onChanged: _validateNit,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Solo números';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Razón Social',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog first!
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text(
              'CERRAR SESIÓN',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: (_loading || _isValidating || !_isNitValid)
                ? null
                : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(150, 45),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('GUARDAR Y CONTINUAR'),
          ),
        ],
      ),
    );
  }
}
