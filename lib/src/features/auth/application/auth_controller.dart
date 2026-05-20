import 'package:dio/dio.dart';
import 'package:e2v_app/src/features/auth/data/auth_api.dart';
import 'package:e2v_app/src/features/auth/data/token_store.dart';
import 'package:e2v_app/src/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authApiProvider = Provider((ref) => AuthApi());
final tokenStoreProvider = Provider((ref) => TokenStore());

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<Map<String, dynamic>?>>(
      (ref) => AuthController(ref),
    );

class AuthController extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  AuthController(this.ref) : super(const AsyncValue.loading()) {
    bootstrap();
  }

  final Ref ref;

  String _parseError(Object e) {
    if (e is DioException) {
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        
        // Handle Laravel validation errors (errors object)
        if (data['errors'] != null && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              return firstError.first.toString();
            }
            return firstError.toString();
          }
        }
        
        // Handle generic message from backend
        if (data['message'] != null) {
          return data['message'].toString();
        }
      }
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Tiempo de espera agotado. Verifica tu conexión.';
      }
      
      if (e.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar al servidor. Inténtalo más tarde.';
      }
      
      return 'Error de conexión al servidor (${e.response?.statusCode ?? '??'}).';
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  Future<void> bootstrap() async {
    try {
      final token = await ref.read(tokenStoreProvider).read().timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw 'Token read timeout',
      );

      if (token == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e) {
      debugPrint('Auth Bootstrap Error: $e');
      // On any error during bootstrap, clear and go to login
      try {
        await ref.read(tokenStoreProvider).clear();
      } catch (_) {}
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final res = await ref
          .read(authApiProvider)
          .login(email: email, password: password);
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(_parseError(e), st);
    }
  }

  Future<void> loginWithGoogle() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      state = AsyncValue.error(
        'El inicio de sesión con Google no está disponible en iOS.',
        StackTrace.current,
      );
      return;
    }
    state = const AsyncValue.loading();
    try {
      debugPrint('🔵 GoogleSignIn: Iniciando flujo de login...');
      
      // Inicializar GoogleSignIn con scopes necesarios
      // serverClientId es necesario para obtener idToken
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile', 'openid'],
        serverClientId: '318186059918-99vl6kkl7i9e6j21dv7422qa3mpe90nh.apps.googleusercontent.com',
      );

      debugPrint('🔵 GoogleSignIn: Intentando hacer signIn()...');
      final account = await googleSignIn.signIn();

      if (account == null) {
        debugPrint('🟡 GoogleSignIn: Usuario canceló el login (account == null)');
        state = const AsyncValue.data(null);
        return;
      }

      debugPrint('🟢 GoogleSignIn: Cuenta obtenida: ${account.email}');

      // Obtener tokens de autenticación
      debugPrint('🔵 GoogleSignIn: Obteniendo tokens de autenticación...');
      final auth = await account.authentication;

      debugPrint('🔵 GoogleSignIn: Información de autenticación:');
      debugPrint('  - accessToken presente: ${auth.accessToken != null}');
      debugPrint('  - idToken presente: ${auth.idToken != null}');

      final idToken = auth.idToken;

      if (idToken == null) {
        debugPrint('🔴 ERROR: idToken es null');
        debugPrint('   Posibles causas:');
        debugPrint('   1. oauth_client vacío en google-services.json');
        debugPrint('   2. SHA-1 del certificado no coincide');
        debugPrint('   3. GoogleService-Info.plist falta en iOS');
        state = AsyncValue.error(
          'No se pudo obtener el token de Google. Verifica la configuración de Firebase:\n'
          '- Android: Revisa que oauth_client no esté vacío en google-services.json\n'
          '- iOS: Asegúrate de que GoogleService-Info.plist existe',
          StackTrace.current,
        );
        return;
      }

      debugPrint('🟢 GoogleSignIn: idToken obtenido exitosamente (primeros 20 chars: ${idToken.substring(0, 20)}...)');

      // Enviar token al backend
      debugPrint('🔵 GoogleSignIn: Enviando token al backend...');
      debugPrint('   Enviando a: ${AppConfig.apiBaseUrl}google-login');
      debugPrint('   ID Token (primeros 50 chars): ${idToken.substring(0, 50)}...');

      final res = await ref.read(authApiProvider).loginWithGoogle(idToken);

      debugPrint('🔵 GoogleSignIn: Respuesta del backend recibida');
      debugPrint('   Status: OK');
      debugPrint('   Keys en respuesta: ${res.keys}');

      if (!res.containsKey('token')) {
        debugPrint('🔴 ERROR: La respuesta no contiene "token"');
        debugPrint('   Respuesta completa: $res');
        state = AsyncValue.error(
          'Backend no retornó token. Respuesta: ${res.toString()}',
          StackTrace.current,
        );
        return;
      }

      final token = res['token'] as String;
      debugPrint('🟢 Token recibido: ${token.substring(0, 20)}...');

      await ref.read(tokenStoreProvider).save(token);

      debugPrint('🔵 Obteniendo perfil...');
      final profile = await ref.read(authApiProvider).profile(token);
      debugPrint('🟢 GoogleSignIn: Login exitoso. Usuario: ${profile['email']}');
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      debugPrint('🔴 ERROR GoogleSignIn: $e');
      debugPrintStack(stackTrace: st);

      // Proporcionar mensajes de error más descriptivos
      String errorMsg = _parseError(e);
      if (e.toString().contains('12501')) {
        errorMsg = 'Cancelaste la autenticación con Google';
      } else if (e.toString().contains('10')) {
        errorMsg = 'Configuración de Google Sign-In incorrecta.\n'
                  'Verifica que:\n'
                  '- SHA-1 (Android) esté registrado en Firebase\n'
                  '- GoogleService-Info.plist (iOS) sea válido';
      }
      state = AsyncValue.error(errorMsg, st);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String billingDocument,
    required String billingDocType,
    required String billingRazonSocial,
    String? nfcId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await ref.read(authApiProvider).register(
        name: name,
        email: email,
        password: password,
        billingDocument: billingDocument,
        billingDocType: billingDocType,
        billingRazonSocial: billingRazonSocial,
        nfcId: nfcId,
      );
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(_parseError(e), st);
    }
  }

  Future<bool> validateField(String field, String value) async {
    try {
      final res = await ref.read(authApiProvider).validateField(field, value);
      return res['available'] ?? true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncValue.data(null);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final current = state.value;
    if (current == null) return;

    final token = current['token'] as String;
    state = const AsyncValue.loading();

    try {
      await ref.read(authApiProvider).updateProfile(token, data);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(_parseError(e), st);
      // Rollback to previous state on error to avoid being stuck in loading
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}
