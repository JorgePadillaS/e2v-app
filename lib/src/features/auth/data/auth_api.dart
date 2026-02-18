import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/config/app_config.dart';

class AuthApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? nfcId,
  }) async {
    final res = await _dio.post('/register', data: {
      'name': name,
      'email': email,
      'password': password,
      if (nfcId != null && nfcId.trim().isNotEmpty) 'nfc_id': nfcId.trim(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/login', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> profile(String token) async {
    final res = await _dio.get(
      '/profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
