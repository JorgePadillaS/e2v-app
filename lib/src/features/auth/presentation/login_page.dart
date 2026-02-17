import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.errorText});
  final String? errorText;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();
  final nfc = TextEditingController();
  bool registerMode = false;

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF131A2A), Color(0xFF1D0F21)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 14,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.zap, color: Colors.amber),
                        SizedBox(width: 10),
                        Text('E2V App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (widget.errorText != null)
                      Text(widget.errorText!, style: const TextStyle(color: Colors.redAccent)),
                    if (registerMode) ...[
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
                      const SizedBox(height: 10),
                    ],
                    TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 10),
                    TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                    if (registerMode) ...[
                      const SizedBox(height: 10),
                      TextField(controller: nfc, decoration: const InputDecoration(labelText: 'NFC ID (opcional)')),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: loading
                          ? null
                          : () async {
                              if (registerMode) {
                                await ref.read(authControllerProvider.notifier).register(
                                      name.text.trim(),
                                      email.text.trim(),
                                      pass.text,
                                      nfcId: nfc.text,
                                    );
                              } else {
                                await ref.read(authControllerProvider.notifier).login(email.text.trim(), pass.text);
                              }
                            },
                      icon: const Icon(LucideIcons.logIn),
                      label: Text(registerMode ? 'Crear cuenta' : 'Ingresar'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Ya tengo cuenta' : 'Crear cuenta nueva'),
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
