import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/config/app_config.dart';
import 'package:e2v_app/src/core/config/branding_config.dart';

class BrandingApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<BrandingConfig> getConfig(String? token) async {
    final res = await _dio.get(
      'config',
      options:
          token != null
              ? Options(headers: {'Authorization': 'Bearer $token'})
              : null,
    );
    return BrandingConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> trackSeen(String token, int promotionId) async {
    await _dio.post(
      'config/seen',
      data: {'promotion_id': promotionId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
