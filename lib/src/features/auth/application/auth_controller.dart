import 'package:e2v_app/src/features/auth/data/auth_api.dart';
import 'package:e2v_app/src/features/auth/data/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authApiProvider = Provider((ref) => AuthApi());
final tokenStoreProvider = Provider((ref) => TokenStore());

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<Map<String, dynamic>?>>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  AuthController(this.ref) : super(const AsyncValue.data(null)) {
    bootstrap();
  }

  final Ref ref;

  Future<void> bootstrap() async {
    final token = await ref.read(tokenStoreProvider).read();
    if (token == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (_) {
      await ref.read(tokenStoreProvider).clear();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await ref.read(authApiProvider).login(email: email, password: password);
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String name, String email, String password, {String? nfcId}) async {
    state = const AsyncValue.loading();
    try {
      final res = await ref.read(authApiProvider).register(
            name: name,
            email: email,
            password: password,
            nfcId: nfcId,
          );
      final token = res['token'] as String;
      await ref.read(tokenStoreProvider).save(token);
      final profile = await ref.read(authApiProvider).profile(token);
      state = AsyncValue.data({'token': token, ...profile});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncValue.data(null);
  }
}
