import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';

class AuthApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  Future<Map<String, dynamic>> validateField(String field, String value) async {
    final res = await _dio.post('validate-field', data: {'field': field, 'value': value});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String billingDocument,
    required String billingDocType,
    required String billingRazonSocial,
    String? nfcId,
  }) async {
    final res = await _dio.post(
      'register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'billing_document': billingDocument,
        'billing_doc_type': billingDocType,
        'billing_razon_social': billingRazonSocial,
        if (nfcId != null && nfcId.trim().isNotEmpty) 'nfc_id': nfcId.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final res = await _dio.post('login', data: {'email': email, 'password': password});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final res = await _dio.post('google-login', data: {'id_token': idToken});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> profile(String token) async {
    final res = await _dio.get('profile', options: Options(headers: {'Authorization': 'Bearer $token'}));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> data) async {
    final res = await _dio.post('profile', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> updateFcmToken(String token, String fcmToken) async {
    await _dio.post('fcm-token', data: {'fcm_token': fcmToken}, options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  Future<void> deleteAccount(String token) async {
    await _dio.delete('profile', options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  Future<Map<String, dynamic>> sendResetPin(String email) async {
    final res = await _dio.post('password/email', data: {'email': email});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _dio.post(
      'password/reset',
      data: {'email': email, 'code': code, 'password': password, 'password_confirmation': passwordConfirmation},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
