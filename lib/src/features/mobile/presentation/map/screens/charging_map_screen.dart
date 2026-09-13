import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/mobile_api.dart';
import '../../../application/stations_notifier.dart';
import '../widgets/station_info_card.dart';
import '../../../../../core/ui/maxvolt_theme.dart';
import '../../../../../core/ui/connector_status.dart';

class ChargingMapScreen extends ConsumerStatefulWidget {
  const ChargingMapScreen({super.key, required this.api});
  final MobileApi api;
  @override
  ConsumerState<ChargingMapScreen> createState() => _ChargingMapScreenState();
}

class _ChargingMapScreenState extends ConsumerState<ChargingMapScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  LatLng? _position;
  Object? _selectedId;
  bool _ready = false, _availableOnly = false;
  String? _type;
  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
      );
      if (!mounted) return;
      setState(() => _position = LatLng(p.latitude, p.longitude));
      if (_ready) _map.move(_position!, 14);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No pudimos obtener tu ubicación. Puedes explorar el mapa.')));
    }
  }

  LatLng? _point(Map<String, dynamic> location) {
    final lat = double.tryParse(location['latitude']?.toString() ?? ''),
        lng = double.tryParse(location['longitude']?.toString() ?? '');
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(stationsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.read(stationsProvider.notifier).fetchStations(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar estaciones'),
          ),
        ),
        data: (locations) {
          final visible = locations
              .where((l) => _point(l) != null && matchesLocation(l, _search.text, _type, _availableOnly))
              .toList();
          final selected = visible.where((l) => l['id'] == _selectedId).firstOrNull ?? visible.firstOrNull;
          final colors = Theme.of(context).colorScheme;
          return LayoutBuilder(
            builder: (context, bounds) => Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter:
                        _position ??
                        (locations.isNotEmpty ? _point(locations.first) : null) ??
                        const LatLng(-17.7833, -63.1821),
                    initialZoom: 13,
                    onMapReady: () {
                      _ready = true;
                      if (_position != null) _map.move(_position!, 14);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'bo.e2v.chargestation',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final location in visible)
                          Marker(
                            point: _point(location)!,
                            width: 100,
                            height: 56,
                            child: Builder(
                              builder: (context) {
                                final connectors = locationConnectors(location);
                                final free = connectors
                                    .where((c) => c['status']?.toString().toUpperCase() == 'AVAILABLE')
                                    .length;
                                final status = free > 0
                                    ? ConnectorStatus.from('AVAILABLE')
                                    : ConnectorStatus.from(connectors.firstOrNull?['status']);
                                return Semantics(
                                  button: true,
                                  label: '${location['name']}: ${free > 0 ? '$free disponibles' : status.label}',
                                  child: Material(
                                    color: status.color,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: Colors.white, width: 2),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() => _selectedId = location['id']);
                                        _map.move(_point(location)!, 14);
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Center(
                                          child: Text(
                                            free > 0 ? '⚡ $free libres' : status.label,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (_position != null)
                          Marker(
                            point: _position!,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: MaxVolt.mint,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '¿Dónde quieres cargar?',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Actualizar estaciones',
                            onPressed: () => ref.read(stationsProvider.notifier).fetchStations(),
                            icon: const Icon(Icons.refresh),
                          ),
                          fillColor: colors.surface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: [
                                FilterChip(
                                  label: const Text('Disponibles'),
                                  selected: _availableOnly,
                                  onSelected: (v) => setState(() => _availableOnly = v),
                                ),
                                for (final type in ['CCS2', 'GB/T'])
                                  FilterChip(
                                    label: Text(type),
                                    selected: _type == type,
                                    onSelected: (v) => setState(() => _type = v ? type : null),
                                  ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Mi ubicación',
                            onPressed: _locate,
                            icon: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: colors.surface,
                          child: InkWell(
                            onTap: () => launchUrl(
                              Uri.parse('https://www.openstreetmap.org/copyright'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10)),
                            ),
                          ),
                        ),
                      ),
                      if (selected != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: bounds.maxHeight * .50),
                          child: StationInfoCard(
                            key: ValueKey(selected['id']),
                            station: selected,
                            userLocation: _position,
                            onClose: () {},
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          color: colors.surface,
                          child: const Text('No hay estaciones que coincidan con estos filtros.'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}
