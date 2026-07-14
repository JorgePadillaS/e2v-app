import 'package:firebase_remote_config/firebase_remote_config.dart';

class AppConfig {
  static String _apiBaseUrl = 'https://epservice.dmc.bo/api/v1/mobile/';
  static String _wsHost = 'epservice.dmc.bo';
  static String _reverbKey = '1d2afbx4y8f4ls8dahrr';
  static String _disclaimerUrl = 'https://www.e2v.bo/disclaimer/';

  static String get apiBaseUrl => _apiBaseUrl;
  static String get wsHost => _wsHost;
  static String get reverbKey => _reverbKey;
  static String get disclaimerUrl => _disclaimerUrl;

  static Future<void> loadRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    await remoteConfig.setDefaults({
      'apiBaseUrl': _apiBaseUrl,
      'wsHost': _wsHost,
      'reverbKey': _reverbKey,
      'disclaimerUrl': _disclaimerUrl,
    });

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
    );

    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // Keep defaults when Remote Config is unavailable.
    }

    _apiBaseUrl = _normalizeApiBaseUrl(_remoteString(remoteConfig, 'apiBaseUrl', fallback: _apiBaseUrl));
    _wsHost = _remoteString(remoteConfig, 'wsHost', fallback: _wsHost);
    _reverbKey = _remoteString(remoteConfig, 'reverbKey', fallback: _reverbKey);
    _disclaimerUrl = _remoteString(remoteConfig, 'disclaimerUrl', fallback: _disclaimerUrl);
  }

  static String _remoteString(FirebaseRemoteConfig remoteConfig, String primaryKey, {required String fallback}) {
    final primaryValue = remoteConfig.getString(primaryKey).trim();
    if (primaryValue.isNotEmpty) return primaryValue;

    return fallback;
  }

  static String _normalizeApiBaseUrl(String value) {
    return value.endsWith('/') ? value : '$value/';
  }
}
