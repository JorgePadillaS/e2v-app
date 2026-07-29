import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/auth_api.dart';
import '../data/token_store.dart';

const _googleServerClientId = '318186059918-99vl6kkl7i9e6j21dv7422qa3mpe90nh.apps.googleusercontent.com';

final authApiProvider = Provider((ref) => AuthApi());
final tokenStoreProvider = Provider((ref) => TokenStore());

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<Map<String, dynamic>?>>(
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

      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
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
      final token = await ref
          .read(tokenStoreProvider)
          .read()
          .timeout(const Duration(seconds: 4), onTimeout: () => throw 'Token read timeout');

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
      final res = await ref.read(authApiProvider).login(email: email, password: password);
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(_parseError(e), st);
    }
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile'], serverClientId: _googleServerClientId);

      final account = await googleSignIn.signIn();
      if (account == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        state = AsyncValue.error('No se pudo obtener el token de Google', StackTrace.current);
        return;
      }

      final res = await ref.read(authApiProvider).loginWithGoogle(idToken);
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(_parseError(e), st);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String billingDocument,
    required String billingDocType,
    required String billingRazonSocial,
    String? nfcId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await ref
          .read(authApiProvider)
          .register(
            name: name,
            email: email,
            password: password,
            phone: phone,
            billingDocument: billingDocument,
            billingDocType: billingDocType,
            billingRazonSocial: billingRazonSocial,
            nfcId: nfcId,
          );
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, 'is_new_user': true, ...profile});
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
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile'], serverClientId: _googleServerClientId);
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google SignOut Error: $e');
    }
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

  Future<void> deleteAccount() async {
    final current = state.value;
    if (current == null) return;

    final token = current['token'] as String;
    state = const AsyncValue.loading();

    try {
      await ref.read(authApiProvider).deleteAccount(token);
      try {
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile'], serverClientId: _googleServerClientId);
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (e) {
        debugPrint('Google SignOut Error: $e');
      }
      await ref.read(tokenStoreProvider).clear();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(_parseError(e), st);
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendResetPin(String email) async {
    try {
      return await ref.read(authApiProvider).sendResetPin(email);
    } catch (e) {
      throw _parseError(e);
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      return await ref
          .read(authApiProvider)
          .resetPassword(email: email, code: code, password: password, passwordConfirmation: passwordConfirmation);
    } catch (e) {
      throw _parseError(e);
    }
  }
}
