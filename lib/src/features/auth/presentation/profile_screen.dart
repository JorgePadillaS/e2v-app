import '../application/auth_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/ui/app_toast.dart';
import '../../../core/config/branding_provider.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'vehicles_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _nitController;
  late TextEditingController _razonSocialController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;
  bool _isLoading = false;
  bool _isEditing = false;

  late String _initialName;
  late String _initialPhone;
  late String _initialNit;
  late String _initialRazonSocial;

  bool get _hasChanges {
    return _nameController.text != _initialName ||
        _phoneController.text.trim() != _initialPhone ||
        _nitController.text.trim() != _initialNit ||
        _razonSocialController.text != _initialRazonSocial ||
        _passwordController.text.isNotEmpty ||
        _passwordConfirmController.text.isNotEmpty;
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _initialName;
      _phoneController.text = _initialPhone;
      _nitController.text = _initialNit;
      _razonSocialController.text = _initialRazonSocial;
      _passwordController.clear();
      _passwordConfirmController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    final authData = ref.read(authControllerProvider).value;
    final user = authData?['user'] as Map? ?? {};

    _nameController = TextEditingController(text: user['name']?.toString() ?? '');
    _phoneController = TextEditingController(text: user['phone']?.toString() ?? '');
    _nitController = TextEditingController(text: user['billing_document']?.toString() ?? '');
    _razonSocialController = TextEditingController(text: user['billing_razon_social']?.toString() ?? '');
    _passwordController = TextEditingController();
    _passwordConfirmController = TextEditingController();

    _initialName = _nameController.text;
    _initialPhone = _phoneController.text.trim();
    _initialNit = _nitController.text.trim();
    _initialRazonSocial = _razonSocialController.text;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nitController.dispose();
    _razonSocialController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<bool> _showDiscardDialog() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tienes modificaciones sin guardar. ¿Deseas salir y descartar los cambios?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar Editando')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro de que deseas cerrar tu sesión en esta cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al cerrar sesión: $e', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.isNotEmpty) {
      final passVal = _passwordController.text;
      if (passVal.length < 8) {
        showAppToast(context, 'La nueva contraseña debe tener al menos 8 caracteres', type: AppToastType.error);
        return;
      }
      if (!RegExp(r'[A-Z]').hasMatch(passVal)) {
        showAppToast(context, 'La nueva contraseña debe incluir al menos una mayúscula', type: AppToastType.error);
        return;
      }
      if (!RegExp(r'[a-z]').hasMatch(passVal)) {
        showAppToast(context, 'La nueva contraseña debe incluir al menos una minúscula', type: AppToastType.error);
        return;
      }
      if (!RegExp(r'[0-9]').hasMatch(passVal)) {
        showAppToast(context, 'La nueva contraseña debe incluir al menos un número', type: AppToastType.error);
        return;
      }
      if (passVal != _passwordConfirmController.text) {
        showAppToast(context, 'Las contraseñas no coinciden', type: AppToastType.error);
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Guardar cambios?'),
        content: const Text('¿Estás seguro de que deseas guardar las modificaciones realizadas en tu perfil?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'phone': _phoneController.text.trim(),
        'billing_document': _nitController.text.trim(),
        'billing_razon_social': _razonSocialController.text,
        if (_passwordController.text.isNotEmpty) ...{
          'password': _passwordController.text,
          'password_confirmation': _passwordConfirmController.text,
        },
      };

      await ref.read(authControllerProvider.notifier).updateProfile(data);
      if (mounted) {
        setState(() {
          _initialName = _nameController.text;
          _initialPhone = _phoneController.text.trim();
          _initialNit = _nitController.text.trim();
          _initialRazonSocial = _razonSocialController.text;
          _passwordController.clear();
          _passwordConfirmController.clear();
          _isEditing = false;
        });
        showAppToast(context, 'Perfil actualizado correctamente', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        bool canDelete = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('¿Eliminar cuenta permanentemente?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Esta acción es permanente y no se puede deshacer. Se eliminará tu perfil, monedero virtual y todos tus datos personales de acuerdo con el cumplimiento GDPR.\n\nLas sesiones históricas de carga serán anonimizadas.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Para confirmar, escribe "ELIMINAR" a continuación:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'ELIMINAR',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          canDelete = val.trim() == 'ELIMINAR';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: canDelete ? () => Navigator.pop(context, true) : null,
                  style: TextButton.styleFrom(foregroundColor: canDelete ? Colors.red : Colors.grey),
                  child: const Text('Eliminar de todas formas'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (mounted) {
        showAppToast(context, 'Tu cuenta ha sido eliminada correctamente.', type: AppToastType.success);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _showDiscardDialog();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar Perfil' : 'Mi Perfil'),
          leading: _isEditing
              ? IconButton(icon: const Icon(Icons.close), onPressed: _isLoading ? null : _cancelEditing)
              : null,
          actions: [
            if (_isEditing)
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else
                IconButton(onPressed: _save, icon: const Icon(LucideIcons.check))
            else
              IconButton(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(LucideIcons.edit),
                tooltip: 'Editar Perfil',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos Personales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading && _isEditing,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(LucideIcons.user)),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading && _isEditing,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(LucideIcons.phone)),
                ),
                const SizedBox(height: 32),
                Text(
                  'Datos de Facturación (NIT)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nitController,
                  enabled: !_isLoading && _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Documento / NIT',
                    prefixIcon: Icon(LucideIcons.fileText),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El Documento / NIT es obligatorio';
                    }
                    final cleaned = v.trim();
                    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
                      return 'Debe contener solo números';
                    }
                    if (cleaned.length < 5 || cleaned.length > 15) {
                      return 'Debe tener entre 5 y 15 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _razonSocialController,
                  enabled: !_isLoading && _isEditing,
                  decoration: const InputDecoration(labelText: 'Razón Social', prefixIcon: Icon(LucideIcons.building)),
                ),
                const SizedBox(height: 32),
                Text(
                  'Mis Vehículos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    title: const Text('Administrar Vehículos', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Registra tus vehículos y placas de acuerdo con impuestos'),
                    leading: CircleAvatar(
                      backgroundColor: (Theme.of(context).primaryColor).withValues(alpha: 0.1),
                      foregroundColor: Theme.of(context).primaryColor,
                      child: const Icon(LucideIcons.car),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesScreen()));
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Seguridad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading && _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Nueva Contraseña (Opcional)',
                    prefixIcon: Icon(LucideIcons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordConfirmController,
                  enabled: !_isLoading && _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Nueva Contraseña',
                    prefixIcon: Icon(LucideIcons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                const _LegalSection(),
                const SizedBox(height: 40),
                if (_isEditing) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _isLoading ? null : _save, child: const Text('Guardar Cambios')),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _cancelEditing,
                      child: const Text('Cancelar Edición'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isEditing = true),
                      child: const Text('Editar Perfil'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade800),
                      ),
                      child: const Text('Cerrar Sesión'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _deleteAccount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Eliminar Cuenta (GDPR)'),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                const _AppVersionWidget(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection extends ConsumerWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider).value;
    if (branding == null || !branding.legal.isDisclaimerVisible) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información Legal',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aviso Legal y Disclaimers'),
          subtitle: const Text('Términos y condiciones de uso'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () async {
            final url = Uri.parse(branding.legal.disclaimerUrl);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}

class _AppVersionWidget extends StatelessWidget {
  const _AppVersionWidget();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final info = snapshot.data!;
        return Center(
          child: Text(
            'Versión ${info.version} (${info.buildNumber})',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        );
      },
    );
  }
}
