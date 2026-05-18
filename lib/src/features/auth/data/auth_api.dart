import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/config/app_config.dart';
import 'package:flutter/foundation.dart';

class AuthApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  Future<Map<String, dynamic>> validateField(String field, String value) async {
    final res = await _dio.post(
      'validate-field',
      data: {'field': field, 'value': value},
    );
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

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      'login',
      data: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final res = await _dio.post(
        'google-login',
        data: {'id_token': idToken},
      );
      debugPrint('✅ Google Login Response: ${res.statusCode}');
      debugPrint('Response data: ${res.data}');

      if (res.data is! Map) {
        throw Exception('Response is not a Map: ${res.data.runtimeType}');
      }

      final data = Map<String, dynamic>.from(res.data as Map);

      // Verificar si la respuesta tiene 'token'
      if (!data.containsKey('token')) {
        debugPrint('⚠️ Response no tiene "token". Keys: ${data.keys}');
        debugPrint('Full response: $data');
      }

      return data;
    } catch (e) {
      debugPrint('❌ Error en loginWithGoogle: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> profile(String token) async {
    final res = await _dio.get(
      'profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.post(
      'profile',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> updateFcmToken(String token, String fcmToken) async {
    await _dio.post(
      'fcm-token',
      data: {'fcm_token': fcmToken},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
