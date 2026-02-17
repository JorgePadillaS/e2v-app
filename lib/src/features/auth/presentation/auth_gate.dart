import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:e2v_app/src/features/auth/presentation/home_page.dart';
import 'package:e2v_app/src/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => LoginPage(errorText: e.toString()),
      data: (data) {
        if (data == null || data['user'] == null) return const LoginPage();
        return HomePage(data: data);
      },
    );
  }
}
