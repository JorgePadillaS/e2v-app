import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/mobile/application/stations_notifier.dart';
import 'package:e2v_app/src/features/mobile/presentation/map/widgets/station_info_card.dart';

class ChargingMapScreen extends ConsumerStatefulWidget {
  const ChargingMapScreen({super.key, required this.api});
  final MobileApi api;

  @override
  ConsumerState<ChargingMapScreen> createState() => _ChargingMapScreenState();
}

class _ChargingMapScreenState extends ConsumerState<ChargingMapScreen> {
  Map<String, dynamic>? _selectedLocation;
  LatLng? _userLocation;
  bool _isCardExpanded = false;

  final _defaultCenter = const LatLng(-17.3895, -66.1568); // Cochabamba
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_userLocation!, 14.0);
    }
  }

  void _moveToLocation(Map<String, dynamic> location) {
    final lat = double.tryParse(location['latitude']?.toString() ?? '');
    final lng = double.tryParse(location['longitude']?.toString() ?? '');
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 15.0);
    }
  }

  void _findNearestStation(List<dynamic> locations) {
    if (_userLocation == null || locations.isEmpty) return;

    double? minDistance;
    Map<String, dynamic>? nearestLocation;
    int nearestIndex = -1;

    for (int i = 0; i < locations.length; i++) {
      final loc = Map<String, dynamic>.from(locations[i] as Map);
      final lat = double.tryParse(loc['latitude']?.toString() ?? '');
      final lng = double.tryParse(loc['longitude']?.toString() ?? '');

      if (lat != null && lng != null) {
        final distance = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          lat,
          lng,
        );

        if (minDistance == null || distance < minDistance) {
          minDistance = distance;
          nearestLocation = loc;
          nearestIndex = i;
        }
      }
    }

    if (nearestLocation != null) {
      setState(() {
        _selectedLocation = nearestLocation;
        _isCardExpanded = false;
      });
      _moveToLocation(nearestLocation);
      if (nearestIndex != -1) {
        _pageController.animateToPage(
          nearestIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);

    return stationsAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (locations) {
        // Now 'locations' is already the grouped list from StationsNotifier
        final listLocations = locations;
        // But the previous implementation had 'stations' nested in 'location'?
        // No, typically it's Station belongsTo Location.
        // Let's check how the API returns data.
        final markers =
            listLocations
                .map((l) {
                  final lat = double.tryParse(l['latitude']?.toString() ?? '');
                  final lng = double.tryParse(l['longitude']?.toString() ?? '');

                  if (lat != null && lng != null) {
                    final isSelected = _selectedLocation?['id'] == l['id'];
                    final stations = (l['stations'] as List?) ?? [];

                    // Determine color based on overall status
                    var color = Colors.red;
                    bool hasAvailable = false;
                    bool hasCharging = false;

                    for (var s in stations) {
                      final connectors = (s['connectors'] as List?) ?? [];
                      for (var c in connectors) {
                        final status =
                            (c['status'] ?? '').toString().toUpperCase();
                        if (status == 'AVAILABLE') hasAvailable = true;
                        if (status.contains('CHARG') ||
                            status.contains('OCCUP')) {
                          hasCharging = true;
                        }
                      }
                    }

                    if (hasAvailable) {
                      color = Colors.green;
                    } else if (hasCharging) {
                      color = Colors.amber;
                    }

                    return Marker(
                      point: LatLng(lat, lng),
                      width: isSelected ? 80 : 60,
                      height: isSelected ? 80 : 60,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLocation = l;
                            _isCardExpanded = false; // Reset on new selection
                          });
                          _moveToLocation(l);
                          // Sync page view
                          final index = listLocations.indexOf(l);
                          if (index != -1) {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isSelected)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Container(
                              padding: EdgeInsets.all(isSelected ? 6 : 4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                LucideIcons.zap,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return null;
                })
                .whereType<Marker>()
                .toList();

        // Add user location marker if available
        if (_userLocation != null) {
          markers.add(
            Marker(
              point: _userLocation!,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _userLocation ??
                    (markers.isNotEmpty ? markers.first.point : _defaultCenter),
                initialZoom: 13.0,
                onTap:
                    (_, __) => setState(() {
                      _selectedLocation = null;
                      _isCardExpanded = false;
                    }),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'bo.e2v.electropoint',
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            // FABs
            Positioned(
              top: 16,
              left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'nearest',
                backgroundColor: const Color(0xFF0076D6),
                foregroundColor: Colors.white,
                onPressed: () => _findNearestStation(listLocations),
                icon: const Icon(LucideIcons.navigation2),
                label: const Text(
                  'LLÉVAME A LA ESTACIÓN MÁS CERCANA',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'refresh',
                    onPressed: () {
                      ref.read(stationsProvider.notifier).fetchStations();
                      setState(() {
                        _selectedLocation = null;
                        _isCardExpanded = false;
                      });
                    },
                    child: const Icon(LucideIcons.refreshCw),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'myloc',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0076D6),
                    onPressed: _determinePosition,
                    child: const Icon(LucideIcons.locateFixed),
                  ),
                ],
              ),
            ),

            // Carousel / Info Cards
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                  height:
                      _selectedLocation == null
                          ? 0
                          : (_isCardExpanded
                              ? MediaQuery.of(context).size.height * 0.75
                              : (290.0 * (MediaQuery.maybeTextScalerOf(context)?.scale(1) ?? 1.0)).clamp(290.0, 360.0)),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: listLocations.length,
                    onPageChanged: (index) {
                      final location = listLocations[index];
                      setState(() {
                        _selectedLocation = location;
                        _isCardExpanded = false; // Reset on swipe
                      });
                      _moveToLocation(location);
                    },
                    itemBuilder: (context, index) {
                      final l = listLocations[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: StationInfoCard(
                            station: l,
                            onClose:
                                () => setState(() {
                                  _selectedLocation = null;
                                  _isCardExpanded = false;
                                }),
                            isCarousel: true,
                            userLocation: _userLocation,
                            onExpandChanged: (v) {
                              setState(() => _isCardExpanded = v);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
