import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'App Firebase',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const UsuariosPage(),
  );
}

class UsuariosPage extends StatelessWidget {
  const UsuariosPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('usuarios');

  Future<void> _mostrarFormulario(
    BuildContext context, {
    DocumentReference<Map<String, dynamic>>? referencia,
    Map<String, dynamic>? usuario,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _UsuarioFormDialog(
        usuario: usuario,
        onSave: (datos) async {
          if (referencia == null) {
            await _col.add(datos);
          } else {
            await referencia.update(datos);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios (Firestore)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(d['nombre']?.toString() ?? ''),
                subtitle: Text(
                  '${d['email']?.toString() ?? ''} · '
                  '${d['nocuenta']?.toString() ?? ''}',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Editar usuario',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _mostrarFormulario(
                        context,
                        referencia: docs[i].reference,
                        usuario: d,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar usuario',
                      icon: const Icon(Icons.delete),
                      onPressed: () => docs[i].reference.delete(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(context),
        tooltip: 'Agregar usuario',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _UsuarioFormDialog extends StatefulWidget {
  const _UsuarioFormDialog({required this.onSave, this.usuario});

  final Map<String, dynamic>? usuario;
  final Future<void> Function(Map<String, String> datos) onSave;

  @override
  State<_UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<_UsuarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _emailController;
  late final TextEditingController _nocuentaController;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.usuario?['nombre']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.usuario?['email']?.toString() ?? '',
    );
    _nocuentaController = TextEditingController(
      text: widget.usuario?['nocuenta']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _nocuentaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.onSave({
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'nocuenta': _nocuentaController.text.trim(),
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar la información: $error';
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.usuario != null;

    return AlertDialog(
      title: Text(esEdicion ? 'Editar usuario' : 'Agregar usuario'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el nombre'
                    : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isNotEmpty && !email.contains('@')) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nocuentaController,
                decoration: const InputDecoration(
                  labelText: 'Número de cuenta',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
