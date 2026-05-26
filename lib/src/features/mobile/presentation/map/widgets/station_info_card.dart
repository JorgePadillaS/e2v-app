import 'package:flutter/material.dart';
import 'package:e2v_app/src/features/mobile/application/map_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StationInfoCard extends StatefulWidget {
  const StationInfoCard({
    super.key,
    required this.station,
    required this.onClose,
    this.isCarousel = false,
    this.userLocation,
    this.onExpandChanged,
  });

  final Map<String, dynamic> station;
  final VoidCallback onClose;
  final bool isCarousel;
  final LatLng? userLocation;
  final ValueChanged<bool>? onExpandChanged;

  @override
  State<StationInfoCard> createState() => _StationInfoCardState();
}

class _StationInfoCardState extends State<StationInfoCard> {
  bool _isExpanded = false;

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.station['name']?.toString() ?? 'Ubicación Desconocida';
    final address = widget.station['address']?.toString() ?? 'Dirección no disponible';
    final lat = double.tryParse(widget.station['latitude']?.toString() ?? '');
    final lng = double.tryParse(widget.station['longitude']?.toString() ?? '');
    final googleMapsUrl = widget.station['google_maps_url']?.toString();

    final stations = (widget.station['stations'] as List?) ?? [];

    double? distance;
    if (widget.userLocation != null && lat != null && lng != null) {
      distance = Geolocator.distanceBetween(widget.userLocation!.latitude, widget.userLocation!.longitude, lat, lng);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        margin: widget.isCarousel ? const EdgeInsets.symmetric(vertical: 8) : const EdgeInsets.all(16),
        elevation: 8,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Panel Handle
                if (_isExpanded)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0076D6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.mapPin, color: Color(0xFF0076D6), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                          ),
                          const SizedBox(height: 2),
                          if (distance != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                'A ${_formatDistance(distance)} de ti',
                                style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(LucideIcons.x, size: 20, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 16),

                // Redesigned Toggle Button
                _buildToggleButton(stations.length),

                if (_isExpanded)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: stations.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final s = Map<String, dynamic>.from(stations[index]);
                          final sName = s['name']?.toString() ?? 'Dispensador ${index + 1}';
                          final connectors = (s['connectors'] as List?) ?? [];

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.zap, size: 14, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      sName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF333333)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      connectors.map((c) {
                                        final status = (c['status'] ?? '').toString().toUpperCase();
                                        final isAvailable = status == 'AVAILABLE';
                                        final isBusy = status.contains('CHARG') || status.contains('OCCUP');
                                        final color = isAvailable ? Colors.green : (isBusy ? Colors.amber : Colors.red);

                                        final type = (c['type'] ?? 'Cargador').toString().toUpperCase();
                                        return _buildConnectorBadge(type, color);
                                      }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                        (lat != null && lng != null) ? () => MapService.navigateTo(lat, lng, googleMapsUrl: googleMapsUrl) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0076D6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: const Color(0xFF0076D6).withValues(alpha: 0.4),
                    ),
                    icon: const Icon(LucideIcons.navigation, size: 18),
                    label: const Text(
                      'CÓMO LLEGAR',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(int count) {
    return Material(
      color: _isExpanded ? const Color(0xFF0076D6).withValues(alpha: 0.05) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          final newValue = !_isExpanded;
          if (widget.onExpandChanged != null) {
            widget.onExpandChanged!(newValue);
          }
          setState(() => _isExpanded = newValue);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.layers, size: 18, color: _isExpanded ? const Color(0xFF0076D6) : Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    _isExpanded ? 'OCULTAR DISPENSADORES' : 'VER DISPENSADORES ($count)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.8,
                      color: _isExpanded ? const Color(0xFF0076D6) : const Color(0xFF444444),
                    ),
                  ),
                ],
              ),
              Icon(
                _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 20,
                color: _isExpanded ? const Color(0xFF0076D6) : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorBadge(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.zap, size: 12, color: color),
          const SizedBox(width: 6),
          Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
