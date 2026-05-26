import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:e2v_app/src/core/config/branding_provider.dart';
import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:e2v_app/src/features/auth/presentation/vehicles_screen.dart';

class VehicleSelectorSheet extends ConsumerStatefulWidget {
  const VehicleSelectorSheet({super.key});

  static Future<int?> show(BuildContext context, WidgetRef ref) async {
    return await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const VehicleSelectorSheet(),
    );
  }

  @override
  ConsumerState<VehicleSelectorSheet> createState() => _VehicleSelectorSheetState();
}

class _VehicleSelectorSheetState extends ConsumerState<VehicleSelectorSheet> {
  List<dynamic> _vehicles = [];
  bool _isLoading = true;
  int? _selectedVehicleId;
  late final MobileApi _api;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final token = ref.read(authControllerProvider).value?['token']?.toString() ?? '';
    _api = MobileApi(token);
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await _api.getVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoading = false;
          if (_vehicles.isNotEmpty) {
            _selectedVehicleId = _vehicles.first['id'] as int?;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudieron cargar los vehículos. Por favor, reintenta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider).value;
    final primaryColor = branding?.branding.primaryColor ?? Theme.of(context).primaryColor;
    final mustHaveVehicle = branding?.policies.restrictChargingWithoutVehicle ?? false;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selecciona tu Vehículo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              IconButton(onPressed: () => Navigator.pop(context, null), icon: const Icon(LucideIcons.x)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 48.0), child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadVehicles,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          else if (_vehicles.isEmpty)
            _buildEmptyState(mustHaveVehicle, primaryColor)
          else
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Para cumplir con impuestos nacionales, registraremos los datos de facturación y placa de tu vehículo en esta carga.',
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _vehicles.length + (mustHaveVehicle ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _vehicles.length) {
                          // Optional path: "Continuar sin vehículo"
                          final isSelected = _selectedVehicleId == null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedVehicleId = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryColor.withOpacity(0.04) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? primaryColor : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.minusCircle, color: isSelected ? primaryColor : Colors.grey, size: 24),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Text(
                                        'Continuar sin vehículo',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF333333)),
                                      ),
                                    ),
                                    Radio<int?>(
                                      value: null,
                                      groupValue: _selectedVehicleId,
                                      activeColor: primaryColor,
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedVehicleId = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final vehicle = _vehicles[index];
                        final id = vehicle['id'] as int;
                        final String brand = vehicle['brand']?.toString() ?? '';
                        final String model = vehicle['model']?.toString() ?? '';
                        final String plate = vehicle['plate']?.toString() ?? '';
                        final isSelected = _selectedVehicleId == id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedVehicleId = id;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryColor.withOpacity(0.04) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? primaryColor : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.car,
                                      color: isSelected ? primaryColor : Colors.grey.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$brand $model',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            plate,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Radio<int?>(
                                    value: id,
                                    groupValue: _selectedVehicleId,
                                    activeColor: primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedVehicleId = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesScreen()));
                          _loadVehicles();
                        },
                        icon: Icon(LucideIcons.plusCircle, color: primaryColor, size: 18),
                        label: Text('Agregar nuevo', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedVehicleId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool mustHaveVehicle, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mustHaveVehicle ? Colors.orange.shade50 : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              mustHaveVehicle ? LucideIcons.alertTriangle : LucideIcons.info,
              color: mustHaveVehicle ? Colors.orange : Colors.blue,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            mustHaveVehicle ? 'Vehículo Requerido' : 'Sin Vehículos',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 12),
          Text(
            mustHaveVehicle
                ? 'El sistema tiene restringido iniciar cargas sin registrar un vehículo. De acuerdo con Impuestos Nacionales, se debe registrar la placa antes de suministrar energía.'
                : 'No tienes vehículos registrados en tu cuenta para esta carga. Puedes registrar uno ahora o continuar sin él.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesScreen()));
                  _loadVehicles();
                },
                icon: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
                label: const Text('Registrar Vehículo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          if (!mustHaveVehicle) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context, -1), // Special code for no vehicle
              child: const Text('Continuar sin registrar vehículo', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }
}
