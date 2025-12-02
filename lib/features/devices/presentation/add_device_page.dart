import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wilobu_app/firebase_providers.dart';

class AddDevicePage extends ConsumerStatefulWidget {
  const AddDevicePage({super.key});

  @override
  ConsumerState<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends ConsumerState<AddDevicePage> {
  final _formKey = GlobalKey<FormState>();

  final _wilobuNameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _codeController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _hardwareType = 'HW-A';

  bool _saving = false;

  @override
  void dispose() {
    _wilobuNameController.dispose();
    _ownerController.dispose();
    _codeController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu sesión ha expirado. Ingresa nuevamente.'),
          ),
        );
        context.go('/login');
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final firestore = ref.read(firestoreProvider);

      final name = _wilobuNameController.text.trim().isEmpty
          ? 'Mi Wilobu'
          : _wilobuNameController.text.trim();

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .add({
        'name': name,
        'protectedUser': _ownerController.text.trim(), // puede ser él mismo
        'hardwareId': _codeController.text.trim(),
        'hardwareType': _hardwareType,
        'status': 'En prueba',
        'battery': 0,
        'signal': 0,
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
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
        SnackBar(content: Text('Error al registrar Wilobu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Registrar Wilobu'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutorial simple de vinculación (no técnico / no solo niños)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cómo vincular tu Wilobu',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '1. Enciende el dispositivo Wilobu que quieres vincular.\n'
                          '2. Busca el código Wilobu en la placa del dispositivo o en la tarjeta.\n'
                          '3. Escríbelo exactamente como aparece (sin espacios extra ni errores).\n'
                          '4. Opcional: indica para quién es este Wilobu y un nombre para identificarlo.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Información básica',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                // Nombre amigable del Wilobu
                TextFormField(
                  controller: _wilobuNameController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.watch_outlined),
                    labelText: 'Nombre para este Wilobu (opcional)',
                    hintText: 'Ej: Wilobu personal, Wilobu del trabajo',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // Persona protegida (no solo niños)
                TextFormField(
                  controller: _ownerController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: '¿Para quién es este Wilobu? (opcional)',
                    hintText: 'Ej: Yo mismo, Ana, Mi mamá, etc.',
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                Text(
                  'Código Wilobu',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                    labelText: 'Código Wilobu',
                    hintText: 'Ej: WLB-1234-ABCD',
                    helperText:
                        'Ingresa el código tal como aparece en el dispositivo o en la tarjeta.',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) {
                      return 'Ingresa el código Wilobu.';
                    }
                    if (v.length < 4) {
                      return 'El código parece demasiado corto.';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _hardwareType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de hardware',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'HW-A',
                      child: Text('HW-A (prototipo tarjeta Hologram)'),
                    ),
                    // Aquí luego se agregan HW-B, HW-C, etc.
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _hardwareType = value);
                  },
                ),

                const SizedBox(height: 24),
                Text(
                  'Contacto de emergencia (opcional)',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _emergencyNameController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                    labelText: 'Nombre del contacto',
                    hintText: 'Ej: Mamá, pareja, amigo cercano',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergencyPhoneController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined),
                    labelText: 'Teléfono del contacto',
                    hintText: '+56 9 XXXX XXXX',
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando…' : 'Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
