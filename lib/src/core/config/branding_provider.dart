import 'branding_api.dart';
import 'branding_config.dart';
import '../../features/auth/application/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final brandingApiProvider = Provider((ref) => BrandingApi());

final brandingProvider = AsyncNotifierProvider<BrandingNotifier, BrandingConfig>(() => BrandingNotifier());

class BrandingNotifier extends AsyncNotifier<BrandingConfig> {
  @override
  Future<BrandingConfig> build() async {
    try {
      // Watch auth state to re-fetch config if user logs in/out (token might change available promos)
      // Branding is optional. An authentication error must not be re-thrown
      // while trying to obtain the token, otherwise it is reported as a
      // misleading branding failure.
      final auth = ref.watch(authControllerProvider).asData?.value;
      final token = auth?['token'] as String?;

      return await ref.read(brandingApiProvider).getConfig(token);
    } catch (e, st) {
      // Return fallback on error to ensure app still works
      debugPrint('Error fetching branding: $e');
      debugPrint(st.toString());
      return BrandingConfig.fallback;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authControllerProvider).asData?.value;
      final token = auth?['token'] as String?;
      return await ref.read(brandingApiProvider).getConfig(token);
    });
  }
}
