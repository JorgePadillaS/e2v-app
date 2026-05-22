import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

final stationsProvider = StateNotifierProvider<
  StationsNotifier,
  AsyncValue<List<Map<String, dynamic>>>
>((ref) {
  final authState = ref.watch(authControllerProvider);
  final token = authState.value?['token'] as String?;

  if (token == null) {
    return StationsNotifier(null, ref);
  }

  return StationsNotifier(MobileApi(token), ref);
});

class StationsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  StationsNotifier(this._api, this.ref) : super(const AsyncValue.loading()) {
    if (_api != null) {
      fetchStations();
      _initRealtime();
    }
  }

  final MobileApi? _api;
  final Ref ref;
  StreamSubscription<DatabaseEvent>? _firebaseSubscription;

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchStations() async {
    if (_api == null) return;
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
      
      state = AsyncValue.data(
        grouped.values.where((l) => l['id'] != 0).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      debugPrint("Grouped ${list.length} stations into ${grouped.length} locations");
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _initRealtime() {
    final dbRef = FirebaseDatabase.instance.ref('stations'); // Correct path
    _firebaseSubscription = dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

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
    });
  }
}
