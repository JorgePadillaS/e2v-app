import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/mobile/application/stations_notifier.dart';
import 'package:e2v_app/src/features/mobile/application/map_service.dart';
import 'package:e2v_app/src/features/mobile/presentation/vehicle_selector.dart';
import 'package:e2v_app/src/features/auth/presentation/vehicles_screen.dart';
import 'package:e2v_app/src/features/auth/presentation/profile_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StationsPage extends ConsumerStatefulWidget {
  const StationsPage({super.key, required this.api});
  final MobileApi api;

  @override
  ConsumerState<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends ConsumerState<StationsPage> {
  String? _selectedConnectorId; // Logic: "chargeBoxId-connectorId"
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _reload() async {
    await ref.read(stationsProvider.notifier).fetchStations();
  }

  Map<String, String>? _getActiveSession(List<Map<String, dynamic>> locations) {
    for (var loc in locations) {
      final stations = (loc['stations'] as List? ?? []);
      for (var s in stations) {
        final station = Map<String, dynamic>.from(s as Map);
        final connectors = (station['connectors'] as List? ?? []);
        for (var c in connectors) {
          final con = Map<String, dynamic>.from(c as Map);
          final status = con['status']?.toString().toUpperCase() ?? '';
          if (status.contains('CHARG') || status.contains('OCCUP')) {
            return {
              'chargeBoxId': station['charge_box_id']?.toString() ?? '',
              'connectorId': con['connector_id']?.toString() ?? '1',
            };
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);

    return RefreshIndicator(
      onRefresh: _reload,
      child: stationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [const SizedBox(height: 80), Center(child: Text('Error estaciones: $e'))]),
        data: (locations) {
          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No hay ubicaciones activas (API)', style: TextStyle(color: Colors.grey)),
                  TextButton(onPressed: _reload, child: const Text('Reintentar')),
                ],
              ),
            );
          }

          final activeSession = _getActiveSession(locations);
          final isGlobalLocked = activeSession != null;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            itemBuilder: (_, i) {
              final loc = Map<String, dynamic>.from(locations[i] as Map);
              final stations = (loc['stations'] as List?) ?? const [];

              return _LocationCard(
                location: loc,
                stations: stations,
                api: widget.api,
                selectedConnectorId: _selectedConnectorId,
                activeSession: activeSession,
                isGlobalLocked: isGlobalLocked,
                isProcessing: _isProcessing,
                onConnectorTap: (id) {
                  setState(() => _selectedConnectorId = id);
                },
                onStart: (stationId, chargeBoxId, connectorId) async {
                  final vehicleResult = await VehicleSelectorSheet.show(context, ref);
                  if (!mounted) return;
                  if (vehicleResult == null) {
                    return; // User cancelled
                  }

                  final int? selectedVehicleId = vehicleResult == -1 ? null : vehicleResult;

                  setState(() => _isProcessing = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final res = await widget.api.startStation(
                      stationId,
                      connectorId: int.tryParse(connectorId),
                      vehicleId: selectedVehicleId,
                    );
                    messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Iniciando carga...')));
                  } on DioException catch (e) {
                    final data = e.response?.data;
                    if (data is Map && data['status'] == 'vehicle_required') {
                      _showVehicleRequiredDialog(context, data['message'] ?? 'Se requiere registrar un vehículo.');
                      return;
                    }
                    if (data is Map && data['status'] == 'billing_document_required') {
                      _showBillingDocumentRequiredDialog(
                        context,
                        data['message'] ?? 'Se requiere registrar tu documento de identidad.',
                      );
                      return;
                    }
                    final errorMsg = data?['message'] ?? e.message ?? e.toString();
                    messenger.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    setState(() => _isProcessing = false);
                  }
                },
                onStop: (stationId) async {
                  setState(() => _isProcessing = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final res = await widget.api.stopStation(stationId);
                    messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Deteniendo carga...')));
                  } on DioException catch (e) {
                    final errorMsg = e.response?.data?['message'] ?? e.message ?? e.toString();
                    messenger.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    setState(() => _isProcessing = false);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showVehicleRequiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.orange),
                SizedBox(width: 8),
                Text('Vehículo Requerido', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiclesScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Registrar Vehículo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }

  void _showBillingDocumentRequiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.orange),
                SizedBox(width: 8),
                Text('Documento Requerido', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Completar Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.stations,
    required this.api,
    this.selectedConnectorId,
    this.activeSession,
    required this.isGlobalLocked,
    required this.isProcessing,
    required this.onConnectorTap,
    required this.onStart,
    required this.onStop,
  });

  final Map<String, dynamic> location;
  final List stations;
  final MobileApi api;
  final String? selectedConnectorId;
  final Map<String, String>? activeSession;
  final bool isGlobalLocked;
  final bool isProcessing;
  final Function(String) onConnectorTap;
  final Function(int, String, String) onStart;
  final Function(int) onStop;

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(location['latitude']?.toString() ?? '');
    final lng = double.tryParse(location['longitude']?.toString() ?? '');
    final googleMapsUrl = location['google_maps_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0076D6).withValues(alpha: 0.08), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0076D6), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UBICACIÓN',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0076D6), letterSpacing: 1.1),
                      ),
                      Text(
                        location['name']?.toString() ?? 'Ubicación',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location['address']?.toString() ?? 'Sin dirección',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (lat != null && lng != null)
                  IconButton(
                    icon: const Icon(Icons.navigation, color: Color(0xFF0076D6)),
                    onPressed: () => MapService.navigateTo(lat, lng, googleMapsUrl: googleMapsUrl),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              children:
                  stations.map((s) {
                    final station = Map<String, dynamic>.from(s as Map);
                    final stationId = (station['id'] as num?)?.toInt() ?? 0;
                    final chargeBoxId = station['charge_box_id']?.toString() ?? '';
                    final connectors = (station['connectors'] as List?) ?? const [];

                    final isThisStationActive = activeSession?['chargeBoxId'] == chargeBoxId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isThisStationActive ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isThisStationActive ? Colors.blue.shade200 : Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.ev_station,
                                size: 20,
                                color: isThisStationActive ? const Color(0xFF0076D6) : const Color(0xFF444444),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  station['name']?.toString() ?? 'Cargador',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isThisStationActive ? const Color(0xFF0076D6) : const Color(0xFF333333),
                                  ),
                                ),
                              ),
                              Text(
                                'ID: $chargeBoxId',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children:
                                connectors.map((c) {
                                  final con = Map<String, dynamic>.from(c as Map);
                                  final conId = con['connector_id']?.toString() ?? '1';
                                  final fullId = "$chargeBoxId-$conId";
                                  final status = con['status']?.toString().toUpperCase() ?? 'UNKNOWN';
                                  final isAvailable = status == 'AVAILABLE';
                                  final isCharging = status.contains('CHARG') || status.contains('OCCUP');
                                  final isSelected = selectedConnectorId == fullId;

                                  final color =
                                      isAvailable
                                          ? (isSelected ? const Color(0xFF0076D6) : Colors.green.shade600)
                                          : (isCharging ? Colors.orange.shade700 : Colors.red.shade600);

                                  return GestureDetector(
                                    onTap: isAvailable ? () => onConnectorTap(fullId) : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF0076D6) : color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF0076D6) : color.withValues(alpha: 0.4),
                                          width: 2,
                                        ),
                                        boxShadow:
                                            isSelected
                                                ? [
                                                  BoxShadow(
                                                    color: Colors.blue.withValues(alpha: 0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                                : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bolt, size: 14, color: isSelected ? Colors.white : color),
                                          const SizedBox(width: 6),
                                          Text(
                                            con['type']?.toString() ?? 'Cargador',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected ? Colors.white : color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon:
                                      isProcessing
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                          : const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('START'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0076D6),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    disabledBackgroundColor: Colors.grey.shade300,
                                  ),
                                  onPressed:
                                      (isProcessing ||
                                              isGlobalLocked ||
                                              selectedConnectorId == null ||
                                              !selectedConnectorId!.startsWith(chargeBoxId))
                                          ? null
                                          : () => onStart(stationId, chargeBoxId, selectedConnectorId!.split('-').last),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.stop, size: 18),
                                  label: const Text('STOP'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isThisStationActive ? Colors.red : const Color(0xFF0076D6),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(
                                      color: isThisStationActive ? Colors.red : const Color(0xFF0076D6),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: (isProcessing || !isThisStationActive) ? null : () => onStop(stationId),
                                ),
                              ),
                            ],
                          ),
                          if (isGlobalLocked && !isThisStationActive)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Hay otra carga activa. Debes detenerla primero.',
                                style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
