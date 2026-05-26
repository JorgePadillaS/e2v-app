import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:e2v_app/src/core/config/branding_provider.dart';
import 'package:e2v_app/src/features/auth/application/auth_controller.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  List<dynamic> _vehicles = [];
  bool _isLoading = true;
  late final MobileApi _api;

  @override
  void initState() {
    super.initState();
    final token = ref.read(authControllerProvider).value?['token']?.toString() ?? '';
    _api = MobileApi(token);
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    try {
      final vehicles = await _api.getVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudieron cargar los vehículos: ${e.toString()}', type: AppToastType.error);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteVehicle(int vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Eliminar vehículo?'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar este vehículo de tu cuenta? Esta acción no afectará a los reportes de las cargas pasadas ya realizadas.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar de todas formas'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _api.deleteVehicle(vehicleId);
      if (mounted) {
        showAppToast(context, 'Vehículo eliminado correctamente.', type: AppToastType.success);
        _loadVehicles();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al eliminar vehículo: ${e.toString()}', type: AppToastType.error);
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddVehicleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:
          (context) => _AddVehicleForm(
            api: _api,
            onSuccess: () {
              Navigator.pop(context);
              _loadVehicles();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider).value;
    final primaryColor = branding?.branding.primaryColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Vehículos', style: TextStyle(fontWeight: FontWeight.bold))),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child:
            _isLoading && _vehicles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _vehicles.isEmpty
                ? _buildEmptyState(primaryColor)
                : _buildVehicleList(primaryColor),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleModal,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Agregar Vehículo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 80.0),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(LucideIcons.car, size: 72, color: primaryColor),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tienes vehículos registrados',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Registra tu vehículo y placa. En cumplimiento con el Servicio de Impuestos Nacionales, se requiere el registro de la placa para facturación y control en las cargas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddVehicleModal,
              icon: const Icon(LucideIcons.plus, color: Colors.white),
              label: const Text(
                'Registrar mi primer vehículo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleList(Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        final String brand = vehicle['brand']?.toString() ?? 'Vehículo';
        final String model = vehicle['model']?.toString() ?? '';
        final String plate = vehicle['plate']?.toString() ?? 'SIN PLACA';
        final String? vin = vehicle['vin']?.toString();
        final double? batteryCapacity =
            vehicle['battery_capacity'] != null ? double.tryParse(vehicle['battery_capacity'].toString()) : null;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.car, color: primaryColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$brand $model',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 8),
                      // Beautiful Bolivian Plate Mockup
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: Text(
                          plate,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (batteryCapacity != null && batteryCapacity > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(LucideIcons.batteryCharging, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Capacidad: $batteryCapacity kWh', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ],
                      if (vin != null && vin.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(LucideIcons.fingerprint, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'VIN: $vin',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteVehicle(vehicle['id'] as int),
                  icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddVehicleForm extends ConsumerStatefulWidget {
  final MobileApi api;
  final VoidCallback onSuccess;

  const _AddVehicleForm({required this.api, required this.onSuccess});

  @override
  ConsumerState<_AddVehicleForm> createState() => _AddVehicleFormState();
}

class _AddVehicleFormState extends ConsumerState<_AddVehicleForm> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();
  final _batteryController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _vinController.dispose();
    _batteryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanedPlate = _plateController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final plateRegex = RegExp(r'^[0-9]{3,4}[A-Z]{3}$');

    if (!plateRegex.hasMatch(cleanedPlate)) {
      showAppToast(context, 'Formato de placa inválido. Debe ser como 123ABC o 1234ABC.', type: AppToastType.error);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final double? capacity = _batteryController.text.isNotEmpty ? double.tryParse(_batteryController.text) : null;

      await widget.api.addVehicle(
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        plate: cleanedPlate,
        vin: _vinController.text.trim().isNotEmpty ? _vinController.text.trim() : null,
        batteryCapacity: capacity,
      );

      if (mounted) {
        showAppToast(context, 'Vehículo registrado exitosamente.', type: AppToastType.success);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al registrar vehículo: ${e.toString()}', type: AppToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider).value;
    final primaryColor = branding?.branding.primaryColor ?? Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registrar Vehículo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ej. Tesla, BYD, Nissan, Toyota',
                  prefixIcon: Icon(LucideIcons.tag),
                ),
                validator: (v) => v == null || v.isEmpty ? 'La marca es requerida' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Ej. Model 3, Song Plus, Leaf',
                  prefixIcon: Icon(LucideIcons.car),
                ),
                validator: (v) => v == null || v.isEmpty ? 'El modelo es requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Número de Placa',
                  hintText: 'Ej. 123ABC o 1234ABC',
                  prefixIcon: Icon(LucideIcons.hash),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'La placa es requerida';
                  final cleaned = v.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
                  final plateRegex = RegExp(r'^[0-9]{3,4}[A-Z]{3}$');
                  if (!plateRegex.hasMatch(cleaned)) {
                    return 'Formato boliviano inválido (ej: 1234ABC)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _batteryController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Capacidad de Batería (kWh) - Opcional',
                  hintText: 'Ej. 60.5',
                  prefixIcon: Icon(LucideIcons.battery),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vinController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Número de Chasis / VIN / VID - Opcional',
                  hintText: 'Ej. 1HGCR2F83HA000000',
                  prefixIcon: Icon(LucideIcons.fingerprint),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                          : const Text(
                            'Registrar Vehículo',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
