import '../data/mobile_api.dart';
import '../../auth/application/auth_controller.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';

final stationsProvider = StateNotifierProvider<StationsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final authState = ref.watch(authControllerProvider);
  final token = authState.asData?.value?['token'] as String?;

  if (token == null) {
    return StationsNotifier(null, ref);
  }

  return StationsNotifier(MobileApi(token), ref);
});

class StationsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  StationsNotifier(this._api, this.ref) : super(const AsyncValue.loading()) {
    if (_api != null) {
      fetchStations();
      _initRealtime();
      _polling = Timer.periodic(const Duration(seconds: 30), (_) => fetchStations());
    }
  }

  final MobileApi? _api;
  final Ref ref;
  StreamSubscription<QuerySnapshot>? _firebaseSubscription;
  Timer? _polling;
  bool _fetching = false;

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _polling?.cancel();
    super.dispose();
  }

  Future<void> fetchStations() async {
    if (_api == null || _fetching) return;
    _fetching = true;
    try {
      final list = await _api.stations();

      final Map<int, Map<String, dynamic>> grouped = {};

      for (final s in list) {
        final station = Map<String, dynamic>.from(s as Map);
        final location = Map<String, dynamic>.from(station['location'] as Map? ?? {});
        final locId = (location['id'] as num?)?.toInt() ?? 0;

        if (!grouped.containsKey(locId)) {
          grouped[locId] = {
            'id': locId,
            'name': location['name'] ?? 'Ubicación Desconocida',
            'address': location['address'] ?? '',
            'latitude': location['latitude'],
            'longitude': location['longitude'],
            'google_maps_url': location['google_maps_url'],
            'stations': [],
          };
        }

        (grouped[locId]!['stations'] as List).add(station);
      }

      if (!mounted) return;
      state = AsyncValue.data(
        grouped.values.where((l) => l['id'] != 0).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      debugPrint("Grouped ${list.length} stations into ${grouped.length} locations");
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    } finally {
      _fetching = false;
    }
  }

  void _initRealtime() {
    final dbRef = FirebaseFirestore.instance.collection('maxvolt_stations');
    _firebaseSubscription = dbRef.snapshots().listen(
      (event) {
        final Map<String, dynamic> data = {};
        for (var doc in event.docs) {
          data[doc.id] = doc.data();
        }
        if (data.isEmpty) return;

        if (state.hasValue) {
          final currentLocations = state.value!;
          bool updated = false;

          final updatedLocations = currentLocations.map((loc) {
            Map<String, dynamic> updatedLoc = Map<String, dynamic>.from(loc);
            final stations = (updatedLoc['stations'] as List? ?? []);

            bool locUpdated = false;
            final updatedStations = stations.map((s) {
              Map<String, dynamic> stationMap = Map<String, dynamic>.from(s as Map);
              final chargeBoxId = stationMap['charge_box_id']?.toString();

              if (chargeBoxId != null && data.containsKey(chargeBoxId)) {
                final stationData = data[chargeBoxId] as Map?;
                if (stationData != null) {
                  final connectorsUpdate = stationData['connectors'] as Map?;
                  if (connectorsUpdate != null) {
                    final connectors = List<Map<String, dynamic>>.from(
                      (stationMap['connectors'] as List? ?? []).map((c) => Map<String, dynamic>.from(c as Map)),
                    );

                    for (var connector in connectors) {
                      final conId = connector['connector_id']?.toString();
                      if (conId != null && connectorsUpdate.containsKey(conId)) {
                        final conData = connectorsUpdate[conId] as Map?;
                        final conStatus = conData?['status']?.toString().toUpperCase();
                        if (conStatus != null && connector['status'] != conStatus) {
                          connector['status'] = conStatus;
                          locUpdated = true;
                          updated = true;
                          debugPrint("Real-time update: Station $chargeBoxId, Connector $conId -> $conStatus");
                        }
                      }
                    }
                    stationMap['connectors'] = connectors;
                  }
                }
              }
              return stationMap;
            }).toList();

            if (locUpdated) {
              updatedLoc['stations'] = updatedStations;
            }
            return updatedLoc;
          }).toList();

          if (updated) {
            state = AsyncValue.data(updatedLocations);
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Realtime status is an enhancement over the station list loaded from
        // the API. Keep that data usable when Firebase rules or connectivity
        // reject the listener instead of surfacing an unhandled stream error.
        debugPrint('Station realtime updates unavailable: $error');
      },
    );
  }
}
