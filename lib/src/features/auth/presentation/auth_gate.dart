import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/auth_controller.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'splash_screen.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/config/app_config.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.maybeWhen(
      loading: () => const SplashScreen(),
      data: (data) {
        if (data == null || data['user'] == null) return const LoginPage();

        // Initialize WebSocket Service for Real-time Status
        WebsocketService().init(host: AppConfig.wsHost, apiKey: AppConfig.reverbKey);

        return HomePage(data: data);
      },
      orElse: () => const LoginPage(),
    );
  }
}
