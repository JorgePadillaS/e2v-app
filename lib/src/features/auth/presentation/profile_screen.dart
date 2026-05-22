import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:e2v_app/src/core/config/branding_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nitController;
  late TextEditingController _razonSocialController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authData = ref.read(authControllerProvider).value;
    final user = authData?['user'] as Map? ?? {};

    _nameController = TextEditingController(
      text: user['name']?.toString() ?? '',
    );
    _nitController = TextEditingController(
      text: user['billing_document']?.toString() ?? '',
    );
    _razonSocialController = TextEditingController(
      text: user['billing_razon_social']?.toString() ?? '',
    );
    _passwordController = TextEditingController();
    _passwordConfirmController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nitController.dispose();
    _razonSocialController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.isNotEmpty &&
        _passwordController.text != _passwordConfirmController.text) {
      showAppToast(
        context,
        'Las contraseñas no coinciden',
        type: AppToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'billing_document': _nitController.text,
        'billing_razon_social': _razonSocialController.text,
        if (_passwordController.text.isNotEmpty) ...{
          'password': _passwordController.text,
          'password_confirmation': _passwordConfirmController.text,
        },
      };

      await ref.read(authControllerProvider.notifier).updateProfile(data);
      if (mounted) {
        showAppToast(
          context,
          'Perfil actualizado correctamente',
          type: AppToastType.success,
        );
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(onPressed: _save, icon: const Icon(LucideIcons.check)),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: Icon(LucideIcons.user),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 32),
              Text(
                'Datos de Facturación (NIT)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nitController,
                decoration: const InputDecoration(
                  labelText: 'Documento / NIT',
                  prefixIcon: Icon(LucideIcons.fileText),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _razonSocialController,
                decoration: const InputDecoration(
                  labelText: 'Razón Social',
                  prefixIcon: Icon(LucideIcons.building),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Seguridad',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Nueva Contraseña (Opcional)',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordConfirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirmar Nueva Contraseña',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              const _LegalSection(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: const Text('Guardar Cambios'),
                ),
              ),
            ],
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
