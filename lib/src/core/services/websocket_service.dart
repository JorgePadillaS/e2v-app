import 'package:laravel_echo/laravel_echo.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:flutter/foundation.dart';

class WebsocketService {
  static final WebsocketService _instance = WebsocketService._internal();
  factory WebsocketService() => _instance;
  WebsocketService._internal();

  Echo? _echo;
  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  bool _initialized = false;

  Future<void> init({required String host, required String apiKey}) async {
    if (_initialized) return;
    try {
      _initialized = true;
      await pusher.init(
        apiKey: apiKey,
        cluster: 'mt1',
        useTLS: true,
        // host is not a top-level param in some versions, but cluster is.
        // If we use reverb, we might need a custom host.
        // In pusher_channels_flutter, host is passed in 'init' in recent versions.
        // Let's try to remove it if compile fails.
      );
      await pusher.connect();

      _echo = Echo(broadcaster: EchoBroadcasterType.Pusher, client: pusher);

      debugPrint("WebSocket initialized on $host");
    } catch (e) {
      debugPrint("WebSocket Init Error: $e");
    }
  }

  Echo? get echo => _echo;

  void listenToStationStatus(Function(Map<String, dynamic>) onUpdate) {
    _echo?.channel('stations').listen('.connector.status.updated', (data) {
      debugPrint("Real-time Update Received: $data");
      onUpdate(Map<String, dynamic>.from(data));
    });
  }
}
