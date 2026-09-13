import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../application/map_service.dart';
import '../../../../../core/ui/connector_status.dart';
import '../../../../../core/ui/maxvolt_theme.dart';

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
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final connectors = locationConnectors(widget.station);
    final available = connectors.where((c) => c['status']?.toString().toUpperCase() == 'AVAILABLE').length;
    final lat = double.tryParse(widget.station['latitude']?.toString() ?? ''),
        lng = double.tryParse(widget.station['longitude']?.toString() ?? '');
    final distance = widget.userLocation != null && lat != null && lng != null
        ? Geolocator.distanceBetween(widget.userLocation!.latitude, widget.userLocation!.longitude, lat, lng) / 1000
        : null;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TU PRÓXIMA CARGA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.6),
                  ),
                ),
                Text(
                  '$available disponibles',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.station['name']?.toString() ?? 'Estación',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -1),
            ),
            const SizedBox(height: 5),
            Text(
              [
                if (distance != null) '${distance.toStringAsFixed(1)} km',
                if (widget.station['address']?.toString().isNotEmpty == true) widget.station['address'].toString(),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    connectors.map((c) => c['type']?.toString() ?? '').where((t) => t.isNotEmpty).toSet().join(' · '),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    widget.onExpandChanged?.call(_expanded);
                  },
                  child: Text(_expanded ? 'Ocultar' : 'Conectores'),
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(),
              for (final s in widget.station['stations'] as List? ?? []) ...[
                Text(s['name']?.toString() ?? 'Dispensador', style: Theme.of(context).textTheme.titleSmall),
                for (final c in s['connectors'] as List? ?? [])
                  if ((int.tryParse(c['connector_id']?.toString() ?? '') ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('${c['type'] ?? 'Conector'} · ${c['connector_id']}'),
                          if (c['max_power_kw'] != null) Text('Hasta ${c['max_power_kw']} kW'),
                          Text(
                            ConnectorStatus.from(c['status']).label,
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                if (s['tariff'] is Map && s['tariff']['price_kwh'] != null)
                  Text('${s['tariff']['currency'] ?? 'BOB'} ${s['tariff']['price_kwh']} / kWh'),
              ],
              const Text('La potencia disponible puede compartirse entre conectores.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: lat == null || lng == null
                    ? null
                    : () =>
                          MapService.navigateTo(lat, lng, googleMapsUrl: widget.station['google_maps_url']?.toString()),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Cómo llegar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
