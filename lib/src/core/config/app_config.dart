import 'package:firebase_remote_config/firebase_remote_config.dart';

class AppConfig {
  static String _apiBaseUrl = 'https://maxvolt.net/api/v1/mobile/';
  static String _wsHost = 'maxvolt.net';
  static String _reverbKey = '';
  static String _disclaimerUrl = 'https://maxvolt.net/disclaimer';
  static String get apiBaseUrl => _apiBaseUrl;
  static String get wsHost => _wsHost;
  static String get reverbKey => _reverbKey;
  static String get disclaimerUrl => _disclaimerUrl;

  /// Isolated keys: cached MaxVolt Remote Config must never reroute MaxVolt.
  static Future<void> loadRemoteConfig() async {
    try {
      final remote = FirebaseRemoteConfig.instance;
      await remote.setDefaults({
        'maxvolt_apiBaseUrl': _apiBaseUrl,
        'maxvolt_wsHost': _wsHost,
        'maxvolt_reverbKey': _reverbKey,
        'maxvolt_disclaimerUrl': _disclaimerUrl,
      });
      await remote.setConfigSettings(
        RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
      );
      await remote.fetchAndActivate();
      _apiBaseUrl = trustedUrl(remote.getString('maxvolt_apiBaseUrl'), _apiBaseUrl, trailingSlash: true);
      _disclaimerUrl = trustedUrl(remote.getString('maxvolt_disclaimerUrl'), _disclaimerUrl);
      final host = remote.getString('maxvolt_wsHost').trim();
      if (host == 'maxvolt.net' || host.endsWith('.maxvolt.net')) _wsHost = host;
      _reverbKey = remote.getString('maxvolt_reverbKey').trim();
    } catch (_) {
      /* The bundled MaxVolt endpoint remains available offline. */
    }
  }

  static String trustedUrl(String value, String fallback, {bool trailingSlash = false}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.host == 'maxvolt.net' || uri.host.endsWith('.maxvolt.net')))
      return fallback;
    final result = uri.toString();
    return trailingSlash && !result.endsWith('/') ? '$result/' : result;
  }
}
