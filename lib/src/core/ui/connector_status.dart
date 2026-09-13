import 'package:flutter/material.dart';

import 'maxvolt_theme.dart';

class ConnectorStatus {
  const ConnectorStatus(this.label, this.color);
  final String label;
  final Color color;
  static ConnectorStatus from(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'AVAILABLE' => const ConnectorStatus('Disponible', MaxVolt.forest),
      'PREPARING' => const ConnectorStatus('Preparando', Color(0xFF956000)),
      'CHARGING' || 'OCCUPIED' => const ConnectorStatus('En uso', Color(0xFF245C94)),
      'SUSPENDEDEV' => const ConnectorStatus('Pausada por el vehículo', Color(0xFF956000)),
      'SUSPENDEDEVSE' => const ConnectorStatus('Pausada por la estación', Color(0xFF956000)),
      'FINISHING' => const ConnectorStatus('Finalizando', Color(0xFF246E82)),
      'FAULTED' => const ConnectorStatus('Averiado', Color(0xFFB3261E)),
      'OFFLINE' || 'UNAVAILABLE' => const ConnectorStatus('Sin conexión / no disponible', Color(0xFF596662)),
      'RESERVED' => const ConnectorStatus('Reservado', Color(0xFF675080)),
      _ => const ConnectorStatus('Estado desconocido', Color(0xFF596662)),
    };
  }
}

List<Map<String, dynamic>> locationConnectors(Map<String, dynamic> location) => [
  for (final station in (location['stations'] as List? ?? []))
    for (final connector in (station['connectors'] as List? ?? []))
      if ((int.tryParse(connector['connector_id']?.toString() ?? '') ?? 0) > 0)
        Map<String, dynamic>.from(connector as Map),
];

bool matchesLocation(Map<String, dynamic> location, String query, String? type, bool availableOnly) {
  final text = '${location['name']} ${location['address']}'.toLowerCase();
  if (!text.contains(query.trim().toLowerCase())) return false;
  if (type == null && !availableOnly) return true;
  return locationConnectors(location).any(
    (c) =>
        (type == null || c['type']?.toString().toUpperCase().replaceAll('/', '') == type.replaceAll('/', '')) &&
        (!availableOnly || c['status']?.toString().toUpperCase() == 'AVAILABLE'),
  );
}
