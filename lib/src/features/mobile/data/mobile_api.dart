import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/config/app_config.dart';

class MobileApi {
  MobileApi(this.token)
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ));

  final String token;
  final Dio _dio;

  Future<List<dynamic>> stations() async {
    final res = await _dio.get('/stations');
    return (res.data as List).toList();
  }

  Future<Map<String, dynamic>> wallet() async {
    final res = await _dio.get('/wallet');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> walletTransactions() async {
    final res = await _dio.get('/wallet/transactions');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> topup(double amount) async {
    final res = await _dio.post('/wallet/topup', data: {'amount': amount});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> libelulaCheckout(double amount) async {
    final res = await _dio.post('/wallet/libelula/checkout', data: {'amount': amount});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> sessions() async {
    final res = await _dio.get('/sessions');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> startStation(int stationId) async {
    final res = await _dio.post('/stations/$stationId/start');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> stopStation(int stationId) async {
    final res = await _dio.post('/stations/$stationId/stop');
    return Map<String, dynamic>.from(res.data as Map);
  }
}
