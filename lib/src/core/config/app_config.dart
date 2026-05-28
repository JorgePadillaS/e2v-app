import 'package:firebase_remote_config/firebase_remote_config.dart';

class AppConfig {
  static const String _defaultApiBaseUrl = ''; //'https://e2v.evbol.com/api/v1/mobile/';
  static const String _defaultWsHost = ''; //'e2v.evbol.com';
  static const String _defaultReverbKey = ''; //'1d2afbx4y8f4ls8dahrr';
  static const String _defaultDisclaimerUrl = '';

  static String _apiBaseUrl = _defaultApiBaseUrl;
  static String _wsHost = _defaultWsHost;
  static String _reverbKey = _defaultReverbKey;
  static String _disclaimerUrl = _defaultDisclaimerUrl;

  static String get apiBaseUrl => _apiBaseUrl;
  static String get wsHost => _wsHost;
  static String get reverbKey => _reverbKey;
  static String get disclaimerUrl => _disclaimerUrl;

  static Future<void> loadRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    await remoteConfig.setDefaults({
      'apiBaseUrl': _defaultApiBaseUrl,
      'wsHost': _defaultWsHost,
      'reverbKey': _defaultReverbKey,
      'disclaimerUrl': _defaultDisclaimerUrl,
    });

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
    );

    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // Keep defaults when Remote Config is unavailable.
    }

    _apiBaseUrl = _normalizeApiBaseUrl(_remoteString(remoteConfig, 'apiBaseUrl', fallback: _defaultApiBaseUrl));
    _wsHost = _remoteString(remoteConfig, 'wsHost', fallback: _defaultWsHost);
    _reverbKey = _remoteString(remoteConfig, 'reverbKey', fallback: _defaultReverbKey);
    _disclaimerUrl = _remoteString(remoteConfig, 'disclaimerUrl', fallback: _defaultDisclaimerUrl);
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
