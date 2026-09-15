import 'package:maxvolt_app/src/core/config/app_config.dart';
import 'package:maxvolt_app/src/core/ui/connector_status.dart';
import 'package:maxvolt_app/src/features/mobile/application/active_session_notifier.dart';
import 'package:maxvolt_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

class SessionApi extends MobileApi {
  SessionApi() : super('test');
  bool fail = false, malformed = false, completed = false;
  @override
  Future<Map<String, dynamic>> sessions() async {
    if (fail) throw Exception('offline');
    if (malformed) return {};
    return {
      'data': completed
          ? []
          : [
              {'id': 7, 'status': 'Active'},
            ],
    };
  }
}

void main() {
  test('Failed or malformed polling must not erase an active session', () async {
    final api = SessionApi();
    bool stale = false;
    final notifier = ActiveSessionNotifier(onStale: (s) => stale = s);
    addTearDown(notifier.dispose);
    notifier.startPolling(api);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.value?['id'], 7);
    api.fail = true;
    await notifier.refresh();
    expect(notifier.state.value?['id'], 7);
    expect(stale, isTrue);
    api.fail = false;
    api.malformed = true;
    await notifier.refresh();
    expect(notifier.state.value?['id'], 7);
    api.malformed = false;
    api.completed = true;
    await notifier.refresh();
    expect(notifier.state.value, isNull);
    expect(stale, isFalse);
  });
  test('Domain migration rejects legacy and misleading remote URLs', () {
    const fallback = 'https://maxvolt.net/api/v1/mobile/';
    for (final url in [
      'http://maxvolt.net/api',
      'https://e2v.evbol.com/api',
      'https://maxvolt.net.evil.example/api',
      'https://x@maxvolt.net/api',
    ]) {
      expect(AppConfig.trustedUrl(url, fallback), fallback);
    }
    expect(
      AppConfig.trustedUrl('https://staging.maxvolt.net/api/v1/mobile', fallback, trailingSlash: true),
      'https://staging.maxvolt.net/api/v1/mobile/',
    );
  });
  test('Connector filters combine type and availability on the same connector', () {
    final location = <String, dynamic>{
      'name': 'Central',
      'stations': [
        {
          'connectors': [
            {'connector_id': 1, 'type': 'CCS2', 'status': 'Charging'},
            {'connector_id': 2, 'type': 'GBT', 'status': 'Available'},
          ],
        },
      ],
    };
    expect(matchesLocation(location, 'central', 'CCS2', true), isFalse);
    expect(matchesLocation(location, '', 'GB/T', true), isTrue);
    expect(ConnectorStatus.from('Offline').label, isNot(ConnectorStatus.from('Faulted').label));
  });
}
