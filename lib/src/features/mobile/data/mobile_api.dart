import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/config/app_config.dart';

class MobileApi {
  MobileApi(this.token)
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final String token;
  final Dio _dio;

  Future<List<dynamic>> stations() async {
    final res = await _dio.get('map/stations');
    return (res.data as List).toList();
  }

  Future<List<dynamic>> locations() async {
    final res = await _dio.get('map/locations');
    return (res.data as List).toList();
  }

  Future<Map<String, dynamic>> wallet() async {
    final res = await _dio.get('wallet');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> updateTag(int tagId, String name) async {
    await _dio.post('wallet/tags/$tagId', data: {'name': name});
  }

  Future<Map<String, dynamic>> walletTransactions() async {
    final res = await _dio.get('wallet/transactions');
    return Map<String, dynamic>.from(res.data as Map);
  }

  String walletHistoryDownloadUrl() {
    return '${AppConfig.apiBaseUrl}wallet/history/download?token=$token';
  }

  Future<Map<String, dynamic>> profile(String token) async {
    final res = await _dio.get('profile', options: Options(headers: {'Authorization': 'Bearer $token'}));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> topup(double amount) async {
    final res = await _dio.post('wallet/topup', data: {'amount': amount});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> libelulaCheckout(
    double amount, {
    String? razonSocial,
    String? documento,
    String? complemento,
    String? docType,
  }) async {
    final res = await _dio.post(
      'wallet/libelula/checkout',
      data: {
        'amount': amount,
        if (razonSocial != null) 'razon_social': razonSocial,
        if (documento != null) 'documento': documento,
        if (complemento != null) 'complemento': complemento,
        if (docType != null) 'doc_type': docType,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> libelulaStatus(int transactionId) async {
    try {
      final res = await _dio.get('wallet/libelula/status/$transactionId');
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (_) {
      return Map<String, dynamic>.from({});
    }
  }

  Future<Map<String, dynamic>> deletePendingLibelula(int transactionId) async {
    final res = await _dio.delete('wallet/libelula/pending/$transactionId');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> sessions() async {
    try {
      final res = await _dio.get('sessions');
      return Map<String, dynamic>.from(res.data as Map);
    } on Exception catch (_) {
      return Map<String, dynamic>.from({});
    }
  }

  Future<Map<String, dynamic>> startStation(int stationId, {int? connectorId, int? vehicleId}) async {
    final res = await _dio.post(
      'sessions/$stationId/start',
      data: {if (connectorId != null) 'connector_id': connectorId, if (vehicleId != null) 'vehicle_id': vehicleId},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> stopStation(int stationId) async {
    final res = await _dio.post('sessions/$stationId/stop');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> cancelSession(int sessionId) async {
    final res = await _dio.post('sessions/$sessionId/cancel');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> lookupStation(String chargeBoxId) async {
    final res = await _dio.get('map/stations/lookup', queryParameters: {'charge_box_id': chargeBoxId});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.post('profile', data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> notifications() async {
    final res = await _dio.get('profile/notifications');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> markNotificationAsRead(String id) async {
    final res = await _dio.post('profile/notifications/$id/read');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    final res = await _dio.post('profile/notifications/read-all');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _dio.post('profile/fcm-token', data: {'fcm_token': fcmToken});
  }

  // --- VEHICLES API ---
  Future<List<dynamic>> getVehicles() async {
    final res = await _dio.get('vehicles');
    return (res.data['data'] as List).toList();
  }

  Future<Map<String, dynamic>> addVehicle({
    required String brand,
    required String model,
    required String plate,
    String? vin,
    double? batteryCapacity,
  }) async {
    final res = await _dio.post(
      'vehicles',
      data: {
        'brand': brand,
        'model': model,
        'plate': plate,
        if (vin != null) 'vin': vin,
        if (batteryCapacity != null) 'battery_capacity': batteryCapacity,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> deleteVehicle(int vehicleId) async {
    final res = await _dio.delete('vehicles/$vehicleId');
    return Map<String, dynamic>.from(res.data as Map);
  }
}
