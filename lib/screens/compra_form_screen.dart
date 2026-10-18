import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compra.dart';
import '../models/producto.dart';
import '../repositories/catalogo_repository.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'tiendas_screen.dart';

/// Registra una compra en Historial_Compras y crea su lote.
class CompraFormScreen extends StatefulWidget {
  final Producto producto;
  final int cantidadInicial;
  final int? carritoItemId;

  const CompraFormScreen({
    super.key,
    required this.producto,
    this.cantidadInicial = 1,
    this.carritoItemId,
  });

  @override
  State<CompraFormScreen> createState() => _CompraFormScreenState();
}

class _CompraFormScreenState extends State<CompraFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _cantidad;
  final _precio = TextEditingController();
  int? _tiendaId;
  String _fechaCompra = Fechas.hoyClave();
  String? _caducidad;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cantidad = TextEditingController(text: '${widget.cantidadInicial}');
    _tiendaId = widget.producto.ultimaTiendaId;
    _caducidad = Fechas.masDias(widget.producto.diasAviso + 7);
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _fecha({required bool compra}) async {
    final actual = compra ? _fechaCompra : _caducidad;
    final f = await showDatePicker(
      context: context,
      initialDate: actual == null ? DateTime.now() : Fechas.parse(actual),
      firstDate: DateTime(2020),
      lastDate: compra ? DateTime.now() : DateTime(2035, 12, 31),
      helpText: compra ? 'Fecha de compra' : 'Fecha de caducidad',
    );
    if (f == null) return;
    setState(() {
      if (compra) {
        _fechaCompra = Fechas.clave(f);
      } else {
        _caducidad = Fechas.clave(f);
      }
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final p = widget.producto;
    try {
      await context.read<AlacenaProvider>().registrarCompra(
            Compra(
              productoId: p.id!,
              tiendaId: _tiendaId!,
              cantidad: int.parse(_cantidad.text.trim()),
              precioUnitario: double.tryParse(_precio.text.trim().replaceAll(',', '.')) ?? 0,
              fechaCompra: _fechaCompra,
            ),
            fechaCaducidad: _caducidad,
            carritoItemId: widget.carritoItemId,
          );
      if (!mounted) return;
      mostrarMensaje(context, '🛍️ Compra registrada');
      Navigator.of(context).pop(true);
    } on ReglaException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo registrar: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiendas = context.watch<AlacenaProvider>().tiendas;
    if (_tiendaId != null && !tiendas.any((t) => t.id == _tiendaId)) _tiendaId = null;
    final p = widget.producto;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar compra')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProductoImagen(ruta: p.imagen, icono: p.categoriaIcono, width: 56, height: 56),
              title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Stock actual: ${p.stock} ${p.unidad}'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CampoSelector<int>(
                    valor: _tiendaId,
                    decoration: const InputDecoration(labelText: 'Tienda *', prefixIcon: Icon(Icons.storefront)),
                    items: [
                      for (final t in tiendas) DropdownMenuItem<int>(value: t.id!, child: Text(t.nombre)),
                    ],
                    onChanged: (v) => setState(() => _tiendaId = v),
                    validator: (v) => v == null ? 'Selecciona la tienda' : null,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cantidad,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Cantidad (${p.unidad}) *'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return (n == null || n <= 0) ? 'Mayor a cero' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio unitario', prefixText: '\$ '),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final n = double.tryParse(t.replaceAll(',', '.'));
                      return (n == null || n < 0) ? 'Precio inválido' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.today),
                    title: const Text('Fecha de compra'),
                    trailing: Text(Fechas.corta(_fechaCompra)),
                    onTap: () => _fecha(compra: true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_busy),
                    title: const Text('Caducidad del lote'),
                    subtitle: Text(_caducidad == null ? 'Sin caducidad' : Fechas.corta(_caducidad!)),
                    trailing: Switch(
                      value: _caducidad != null,
                      onChanged: (v) => setState(() => _caducidad = v ? Fechas.masDias(7) : null),
                    ),
                    onTap: () => _fecha(compra: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.check),
              label: const Text('Registrar compra'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
