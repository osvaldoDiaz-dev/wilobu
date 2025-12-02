import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:wilobu_app/firebase_providers.dart';

/// Modelo sencillo para representar un Wilobu visible por BLE.
class NearbyWilobu {
  NearbyWilobu({
    required this.device,
    required this.code,
  });

  final BluetoothDevice device;
  final String code;
}

class AddDevicePage extends ConsumerStatefulWidget {
  const AddDevicePage({super.key});

  @override
  ConsumerState<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends ConsumerState<AddDevicePage> {
  // BLE
  final FlutterBluePlus _ble = FlutterBluePlus.instance;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isScanning = false;
  List<NearbyWilobu> _nearby = [];
  NearbyWilobu? _selectedWilobu;

  // Formulario
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _codeController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _hardwareType = 'HW-A (prototipo tarjeta Hologram)';
  bool _manualCodeMode = false;
  bool _saving = false;

  @override
  void dispose() {
    _stopScan();
    _nameController.dispose();
    _ownerController.dispose();
    _codeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  /// REGLA DE NEGOCIO IMPORTANTE:
  /// Cómo detectamos un Wilobu en el escaneo.
  /// Ahora mismo: por nombre que empieza con "Wilobu" o servicio con UUID fijo.
  static const String _wilobuServiceUuid = '0000ffaa-0000-1000-8000-00805f9b34fb';

  bool _isWilobuDevice(ScanResult r) {
    final name = (r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.device.remoteId.str)
        .toUpperCase();

    if (name.contains('WILOBU')) return true;
    if (r.advertisementData.serviceUuids
        .map((u) => u.toString().toLowerCase())
        .contains(_wilobuServiceUuid)) {
      return true;
    }
    return false;
  }

  /// Cómo extraemos el “código Wilobu” de un dispositivo BLE.
  /// De momento usamos el ID de dispositivo (MAC/UUID). Cuando el firmware
  /// lo exponga en un characteristic o manufacturer data, aquí se ajusta.
  String _codeFromScanResult(ScanResult r) {
    return r.device.remoteId.str;
  }

  Future<void> _ensureBleReady() async {
    // Aquí es donde luego puedes pedir permisos runtime (location, BT, etc.)
    // y mostrar diálogos si algo falta. Por ahora solo intentamos encender BT.
    if (!(await _ble.isOn)) {
      await FlutterBluePlus.turnOn(); // abre diálogo del sistema si aplica
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _nearby = [];
      _selectedWilobu = null;
      if (!_manualCodeMode) {
        _codeController.clear();
      }
    });

    await _ensureBleReady();

    // Cancelar suscripción previa si existiera
    await _scanSub?.cancel();

    // Escaneo de 6 segundos
    await _ble.startScan(
      timeout: const Duration(seconds: 6),
      androidUsesFineLocation: true,
    );

    _scanSub = _ble.scanResults.listen((results) {
      final filtered = results.where(_isWilobuDevice).map((r) {
        return NearbyWilobu(
          device: r.device,
          code: _codeFromScanResult(r),
        );
      }).toList();

      // Evitar duplicados por id
      final byId = <String, NearbyWilobu>{};
      for (final w in filtered) {
        byId[w.device.remoteId.str] = w;
      }

      setState(() {
        _nearby = byId.values.toList();
      });
    });

    // Cuando timeout se cumple, stopScan será llamado internamente,
    // pero mantenemos el flag local en sync.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    if (_isScanning) {
      await _ble.stopScan();
    }
    _isScanning = false;
  }

  void _onSelectWilobu(NearbyWilobu w) {
    setState(() {
      _selectedWilobu = w;
      _manualCodeMode = false;
      _codeController.text = w.code;
    });
  }

  void _toggleManualCode() {
    setState(() {
      _manualCodeMode = !_manualCodeMode;
      if (_manualCodeMode) {
        _selectedWilobu = null;
        _nearby = [];
        _codeController.clear();
      } else {
        // volvemos a modo "código desde BLE"
      }
    });
  }

  Future<void> _save() async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = ref.read(firestoreProvider);

    final user = auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para registrar un Wilobu.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa o selecciona un código Wilobu.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .add({
        'name': _nameController.text.trim().isEmpty
            ? 'Mi Wilobu'
            : _nameController.text.trim(),
        'forWho': _ownerController.text.trim(),
        'code': code,
        'hardwareId': code,
        'hardwareType': _hardwareType,
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        'status': 'Sin conexión',
        'battery': 0,
        'signal': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wilobu registrado correctamente.')),
      );
      context.pop(); // volver al Home
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar Wilobu: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Wilobu'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Tarjeta de instrucciones (adaptada a BLE)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Cómo vincular tu Wilobu',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('1. Enciende el dispositivo Wilobu que quieres vincular.'),
                      Text(
                          '2. Acércalo al teléfono (a menos de 1 metro) y asegúrate de que el Bluetooth esté encendido.'),
                      Text(
                          '3. Pulsa “Buscar Wilobu cercanos” y selecciona el dispositivo que aparezca en la lista.'),
                      Text(
                          '4. Opcional: indica para quién es este Wilobu, un nombre para identificarlo y un contacto de emergencia.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // BLOQUE: ESCANEO BLE
              Text(
                'Wilobus cercanos',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Buscar Wilobu cercanos'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _toggleManualCode,
                    child: Text(_manualCodeMode
                        ? 'Usar detección automática'
                        : 'No encuentro mi Wilobu'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isScanning) ...[
                Row(
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Buscando dispositivos...'),
                  ],
                ),
              ] else if (!_manualCodeMode && _nearby.isEmpty) ...[
                const Text(
                  'No se encontraron Wilobus todavía. '
                  'Enciéndelo y vuelve a buscar.',
                  style: TextStyle(fontSize: 12),
                ),
              ] else if (!_manualCodeMode && _nearby.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._nearby.map((w) {
                  final selected =
                      _selectedWilobu?.device.remoteId == w.device.remoteId;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.watch_outlined,
                        color: selected ? theme.colorScheme.primary : null,
                      ),
                      title: Text(
                        w.device.platformName.isNotEmpty
                            ? w.device.platformName
                            : 'Wilobu (${w.device.remoteId.str})',
                      ),
                      subtitle: Text('Código Wilobu: ${w.code}'),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () => _onSelectWilobu(w),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // INFORMACIÓN BÁSICA
              Text(
                'Información básica',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.watch_outlined),
                  labelText: 'Nombre para este Wilobu (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  labelText: '¿Para quién es este Wilobu? (opcional)',
                ),
              ),

              const SizedBox(height: 24),

              // CÓDIGO WILOBU
              Text(
                'Código Wilobu',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                readOnly: !_manualCodeMode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.qr_code_2_outlined),
                  labelText: 'Código Wilobu',
                  helperText: _manualCodeMode
                      ? 'Escribe el código tal como aparece en el dispositivo o en la tarjeta.'
                      : 'Se completa automáticamente al seleccionar un Wilobu cercano.',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Selecciona un Wilobu o ingresa el código.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _hardwareType,
                items: const [
                  DropdownMenuItem(
                    value: 'HW-A (prototipo tarjeta Hologram)',
                    child: Text('HW-A (prototipo tarjeta Hologram)'),
                  ),
                  DropdownMenuItem(
                    value: 'HW-B (futuro prototipo)',
                    child: Text('HW-B (futuro prototipo)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _hardwareType = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Tipo de hardware',
                ),
              ),

              const SizedBox(height: 24),

              // CONTACTO DE EMERGENCIA
              Text(
                'Contacto de emergencia (opcional)',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyNameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.perm_contact_calendar_outlined),
                  labelText: 'Nombre del contacto',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone_outlined),
                  labelText: 'Teléfono del contacto',
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando...' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
