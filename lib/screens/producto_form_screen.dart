import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../repositories/catalogo_repository.dart';
import '../services/imagen_service.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'categorias_screen.dart';
import 'tiendas_screen.dart';

/// Alta y edición de artículos. La categoría es obligatoria.
class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;
  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _minimo;
  final _cantidad = TextEditingController(text: '1');
  final _precio = TextEditingController();

  int? _categoriaId;
  String _unidad = 'pza';
  int _diasAviso = 3;
  bool _notificar = true;
  String _hora = '09:00';
  String? _imagen;

  // Existencia inicial (solo al crear)
  bool _conExistencia = true;
  String? _caducidad;
  int? _tiendaId;
  bool _guardando = false;

  bool get _editando => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _minimo = TextEditingController(text: '${p?.stockMinimo ?? 1}');
    if (p != null) {
      _categoriaId = p.categoriaId;
      _unidad = p.unidad;
      _diasAviso = p.diasAviso;
      _notificar = p.notificar;
      _hora = p.horaAlarma;
      _imagen = p.imagen;
    } else {
      _caducidad = Fechas.masDias(7);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _minimo.dispose();
    _cantidad.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    final origen = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_imagen != null)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Quitar imagen'),
                onTap: () {
                  setState(() => _imagen = null);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    try {
      final ruta = await ImagenService.seleccionar(origen);
      if (ruta != null && mounted) setState(() => _imagen = ruta);
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo obtener la imagen: $e', error: true);
    }
  }

  Future<void> _elegirHora() async {
    final partes = _hora.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
    );
    if (t != null) {
      setState(() => _hora = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _elegirCaducidad() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _caducidad == null ? DateTime.now() : Fechas.parse(_caducidad!),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Fecha de caducidad',
    );
    if (f != null) setState(() => _caducidad = Fechas.clave(f));
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final prov = context.read<AlacenaProvider>();
    final original = widget.producto;
    final p = Producto(
      id: original?.id,
      nombre: _nombre.text,
      descripcion: _descripcion.text,
      categoriaId: _categoriaId!,
      imagen: _imagen,
      unidad: _unidad,
      stockMinimo: int.parse(_minimo.text.trim()),
      diasAviso: _diasAviso,
      notificar: _notificar,
      horaAlarma: _hora,
    );
    ExistenciaInicial? inicial;
    if (!_editando && _conExistencia) {
      inicial = ExistenciaInicial(
        cantidad: int.parse(_cantidad.text.trim()),
        fechaCaducidad: _caducidad,
        tiendaId: _tiendaId,
        precio: double.tryParse(_precio.text.trim().replaceAll(',', '.')) ?? 0,
      );
    }
    try {
      await prov.guardarProducto(p, inicial: inicial, imagenAnterior: original?.imagen);
      if (!mounted) return;
      mostrarMensaje(context, _editando ? 'Cambios guardados' : '✅ ${p.nombre.trim()} agregado a la alacena');
      Navigator.of(context).pop();
    } on ReglaException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo guardar: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _entero(String? v, {int min = 0}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Escribe un número entero';
    if (n < min) return 'Debe ser al menos $min';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AlacenaProvider>();
    final categorias = prov.categorias;
    final tiendas = prov.tiendas;
    // Si la categoría elegida ya no existe se limpia la selección.
    if (_categoriaId != null && !categorias.any((c) => c.id == _categoriaId)) _categoriaId = null;
    if (_tiendaId != null && !tiendas.any((t) => t.id == _tiendaId)) _tiendaId = null;
    final scheme = Theme.of(context).colorScheme;
    final icono = categorias.where((c) => c.id == _categoriaId).map((c) => c.icono).firstOrNull ?? '📦';

    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar artículo' : 'Nuevo artículo')),
      body: Form(
        key: _form,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _elegirImagen,
                      child: Stack(
                        children: [
                          ProductoImagen(ruta: _imagen, icono: icono, width: 140, height: 140, radius: 28),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: scheme.primary,
                              child: Icon(Icons.photo_camera, size: 18, color: scheme.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Nombre *', prefixIcon: Icon(Icons.label_outline)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoSelector<int>(
                          valor: _categoriaId,
                          decoration: const InputDecoration(labelText: 'Categoría *', prefixIcon: Icon(Icons.category_outlined)),
                          items: [
                            for (final c in categorias)
                              DropdownMenuItem<int>(value: c.id!, child: Text('${c.icono}  ${c.nombre}')),
                          ],
                          onChanged: (v) => setState(() => _categoriaId = v),
                          validator: (v) => v == null ? 'Selecciona una categoría' : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Nueva categoría',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => editarCategoriaDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descripcion,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descripción / marca', prefixIcon: Icon(Icons.notes)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CampoSelector<String>(
                          valor: _unidad,
                          decoration: const InputDecoration(labelText: 'Unidad'),
                          items: [for (final u in unidadesValidas) DropdownMenuItem(value: u, child: Text(u))],
                          onChanged: (v) => setState(() => _unidad = v ?? 'pza'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _minimo,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock mínimo', helperText: 'Alerta "por agotarse"'),
                          validator: (v) => _entero(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Avisar $_diasAviso día(s) antes de caducar',
                      style: Theme.of(context).textTheme.titleSmall),
                  Slider(
                    value: _diasAviso.toDouble(),
                    min: 0,
                    max: 30,
                    divisions: 30,
                    label: '$_diasAviso',
                    onChanged: (v) => setState(() => _diasAviso = v.round()),
                  ),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _notificar,
                          onChanged: (v) => setState(() => _notificar = v),
                          secondary: const Icon(Icons.alarm),
                          title: const Text('Alarma local'),
                          subtitle: const Text('Notificar el día que caduque un lote'),
                        ),
                        if (_notificar)
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const Text('Hora de la alarma'),
                            trailing: Text(_hora, style: Theme.of(context).textTheme.titleMedium),
                            onTap: _elegirHora,
                          ),
                      ],
                    ),
                  ),
                  if (!_editando) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _conExistencia,
                              onChanged: (v) => setState(() => _conExistencia = v),
                              title: const Text('Registrar existencia inicial'),
                              subtitle: const Text('Crea el primer lote (y la compra si eliges tienda)'),
                            ),
                            if (_conExistencia) ...[
                              TextFormField(
                                controller: _cantidad,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'Cantidad ($_unidad)'),
                                validator: (v) => _conExistencia ? _entero(v, min: 1) : null,
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.event),
                                title: Text(_caducidad == null ? 'Sin fecha de caducidad' : 'Caduca: ${Fechas.corta(_caducidad!)}'),
                                trailing: _caducidad == null
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => setState(() => _caducidad = null),
                                      ),
                                onTap: _elegirCaducidad,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: CampoSelector<int?>(
                                      valor: _tiendaId,
                                      decoration: const InputDecoration(labelText: 'Tienda (opcional)'),
                                      items: [
                                        const DropdownMenuItem<int?>(value: null, child: Text('Sin registrar compra')),
                                        for (final t in tiendas)
                                          DropdownMenuItem<int?>(value: t.id, child: Text(t.nombre)),
                                      ],
                                      onChanged: (v) => setState(() => _tiendaId = v),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Nueva tienda',
                                    icon: const Icon(Icons.add_business_outlined),
                                    onPressed: () async {
                                      final id = await editarTiendaDialog(context);
                                      if (id != null && mounted) setState(() => _tiendaId = id);
                                    },
                                  ),
                                ],
                              ),
                              if (_tiendaId != null) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _precio,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Precio unitario', prefixText: '\$ '),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_editando ? 'Guardar cambios' : 'Guardar artículo'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
