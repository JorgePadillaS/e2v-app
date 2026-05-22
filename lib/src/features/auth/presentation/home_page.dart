import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:e2v_app/src/features/mobile/application/active_session_notifier.dart';
import 'package:e2v_app/src/features/mobile/application/wallet_refresh_provider.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/mobile/presentation/nfc_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/sessions_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/stations_page.dart';
import 'package:e2v_app/src/features/mobile/presentation/map/screens/charging_map_screen.dart';
import 'package:e2v_app/src/features/mobile/presentation/wallet_page.dart';
import 'package:e2v_app/src/features/auth/presentation/profile_screen.dart';
import 'package:e2v_app/src/features/mobile/application/notification_notifier.dart';
import 'package:e2v_app/src/features/mobile/presentation/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:e2v_app/src/core/config/branding_provider.dart';
import 'package:dio/dio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  @override
  void initState() {
    super.initState();
    final user = Map<String, dynamic>.from(widget.data['user'] as Map);
    final token = widget.data['token']?.toString() ?? '';
    api = MobileApi(token);

    final assignedTag =
        (widget.data['rfid_tag'] is Map)
            ? (widget.data['rfid_tag']['tag_code']?.toString() ?? '')
            : '';

    _pages = [
      ChargingMapScreen(api: api),
      WalletPage(api: api, displayName: user['name']?.toString()),
      NfcPage(assignedTag: assignedTag, api: api),
      SessionsPage(api: api),
    ];

    // Initial fetch and start polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).startPolling(api);
      ref.read(activeSessionProvider.notifier).startPolling(api);
      _setupFirebaseMessaging();
      _checkPolicies();
      _checkPromotions();
    });
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
      builder: (context) => _MandatoryBillingForm(onComplete: () {
        ref.read(brandingProvider.notifier).refresh();
      }),
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
        builder:
            (context) => AlertDialog(
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
                content: Text(message.notification!.body ?? 'No se pudo iniciar la carga.'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white)),
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
                  onPressed:
                      () => Navigator.push(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final branding = ref.watch(brandingProvider).value;

    final unreadCount = notificationState.maybeWhen(
      data: (data) => (data['unread_count'] as num? ?? 0).toInt(),
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'app_logo',
          child:
              branding?.logoUrl != null
                ? Image.network(
                    branding!.logoUrl!,
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => Image.asset(
                          'assets/logo_leyenda.png',
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                  )
                  : Image.asset(
                    'assets/logo_leyenda.png',
                    height: 38,
                    fit: BoxFit.contain,
                  ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationsPage(api: api),
                      ),
                    ),
                icon: const Icon(LucideIcons.bell),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
            icon: const Icon(LucideIcons.settings),
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) {
          setState(() => index = v);
          if (v == 1) ref.read(walletRefreshProvider.notifier).state++;
          if (v == 2) ref.read(activeSessionProvider.notifier).refresh();
          if (v == 3) ref.read(activeSessionProvider.notifier).refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Billetera',
          ),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Cargar'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Cargas'),
        ],
      ),
    );
  }
}

class _MandatoryBillingForm extends ConsumerStatefulWidget {
  const _MandatoryBillingForm({required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<_MandatoryBillingForm> createState() => _MandatoryBillingFormState();
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
      final available = await ref.read(authControllerProvider.notifier).validateField('billing_document', value);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        title: const Text('Datos de Facturación Requeridos', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Para continuar utilizando la aplicación, debe registrar sus datos según la normativa SIAT.', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                      style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _docType,
                  decoration: const InputDecoration(labelText: 'Tipo de Documento', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                    DropdownMenuItem(value: 'CI', child: Text('Cédula de Identidad')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                  ],
                  onChanged: (v) => setState(() => _docType = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _docType == 'NIT' ? 'Número de NIT' : 'Cédula de Identidad',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _nitError,
                    suffixIcon: _isValidating 
                      ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_isNitValid ? const Icon(Icons.check_circle, color: Colors.green) : null),
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
                  decoration: const InputDecoration(labelText: 'Razón Social', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                  validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
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
            child: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: (_loading || _isValidating || !_isNitValid) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(150, 45),
            ),
            child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text('GUARDAR Y CONTINUAR'),
          ),
        ],
      ),
    );
  }
}
