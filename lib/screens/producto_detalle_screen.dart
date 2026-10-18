import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compra.dart';
import '../models/estatus.dart';
import '../models/lote.dart';
import '../models/producto.dart';
import '../models/tienda.dart';
import '../repositories/catalogo_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'compra_form_screen.dart';
import 'producto_form_screen.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final int productoId;
  final String? heroTag;
  const ProductoDetalleScreen({super.key, required this.productoId, this.heroTag});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  final _inventario = InventarioRepository();
  final _productos = ProductoRepository();

  List<Lote> _lotes = [];
  List<Compra> _compras = [];
  List<TiendaHistorial> _tiendas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lotes = await _inventario.lotesActivos(widget.productoId);
    final compras = await _inventario.comprasDeProducto(widget.productoId);
    final tiendas = await _productos.tiendasDondeSeCompro(widget.productoId);
    if (!mounted) return;
    setState(() {
      _lotes = lotes;
      _compras = compras;
      _tiendas = tiendas;
    });
  }

  Future<void> _ejecutar(Future<void> Function() accion, [String? exito]) async {
    try {
      await accion();
      await _cargar();
      if (mounted && exito != null) mostrarMensaje(context, exito);
    } on ReglaException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'Error: $e', error: true);
    }
  }

  // ---------- Consumir (FEFO) ----------

  /// Simula FEFO para mostrar de qué lotes se descontará.
  List<(Lote, int)> _vistaPreviaFefo(int cantidad) {
    final res = <(Lote, int)>[];
    var restante = cantidad;
    for (final l in _lotes) {
      if (restante <= 0) break;
      final tomar = math.min(l.cantidad, restante);
      res.add((l, tomar));
      restante -= tomar;
    }
    return res;
  }

  Future<void> _consumir(Producto p) async {
    if (p.stock <= 0) {
      mostrarMensaje(context, 'No hay existencia para consumir.', error: true);
      return;
    }
    var cantidad = 1;
    var motivo = 'consumo';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final vista = _vistaPreviaFefo(cantidad);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Descontar de la alacena', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text('Se descuenta primero del lote que caduca antes (FEFO).'),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'consumo', icon: Icon(Icons.restaurant), label: Text('Consumí')),
                    ButtonSegment(value: 'desecho', icon: Icon(Icons.delete_outline), label: Text('Se echó a perder')),
                  ],
                  selected: {motivo},
                  onSelectionChanged: (s) => setM(() => motivo = s.first),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: cantidad > 1 ? () => setM(() => cantidad--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('$cantidad ${p.unidad}', style: Theme.of(ctx).textTheme.headlineSmall),
                    ),
                    IconButton.filledTonal(
                      onPressed: cantidad < p.stock ? () => setM(() => cantidad++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final (l, n) in vista)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.subdirectory_arrow_right),
                    title: Text('$n ${p.unidad} del lote ${l.fechaCaducidad == null ? 'sin caducidad' : 'que caduca ${Fechas.corta(l.fechaCaducidad!)}'}'),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    await _ejecutar(
      () => context.read<AlacenaProvider>().consumir(p.id!, cantidad, motivo: motivo),
      motivo == 'consumo' ? '✅ Se descontaron $cantidad ${p.unidad}' : '🗑️ Registrado como desperdicio',
    );
  }

  // ---------- Lotes ----------

  Future<void> _editarLote(Producto p, [Lote? lote]) async {
    final ctrl = TextEditingController(text: lote == null ? '1' : '${lote.cantidad}');
    String? caducidad = lote?.fechaCaducidad;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(lote == null ? 'Agregar lote' : 'Editar lote'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Cantidad (${p.unidad})'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(caducidad == null ? 'Sin fecha de caducidad' : Fechas.corta(caducidad!)),
                subtitle: const Text('Toca para elegir'),
                trailing: caducidad == null
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () => setD(() => caducidad = null)),
                onTap: () async {
                  final f = await showDatePicker(
                    context: ctx,
                    initialDate: caducidad == null ? DateTime.now() : Fechas.parse(caducidad!),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035, 12, 31),
                  );
                  if (f != null) setD(() => caducidad = Fechas.clave(f));
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final cantidad = int.tryParse(ctrl.text.trim());
    if (ok != true || !mounted) return;
    if (cantidad == null || cantidad <= 0) {
      mostrarMensaje(context, 'La cantidad debe ser un número mayor a cero.', error: true);
      return;
    }
    await _ejecutar(
      () => context.read<AlacenaProvider>().guardarLote(Lote(
            id: lote?.id,
            productoId: p.id!,
            compraId: lote?.compraId,
            cantidad: cantidad,
            fechaCaducidad: caducidad,
            fechaIngreso: lote?.fechaIngreso ?? Fechas.hoyClave(),
          )),
      'Lote guardado',
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AlacenaProvider>();
    final p = prov.productoPorId(widget.productoId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: prov.cargando
            ? const Center(child: CircularProgressIndicator())
            : const EstadoVacio(emoji: '🫙', titulo: 'Producto no encontrado', mensaje: 'Quizá fue eliminado.'),
      );
    }
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final precioMin = _tiendas.isEmpty ? null : _tiendas.map((e) => e.precioMinimo).reduce(math.min);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: p)),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final si = await confirmar(context, '¿Eliminar ${p.nombre}?',
                      'También se eliminarán sus lotes, historial de compras y su lugar en la lista de compras.');
                  if (!si || !context.mounted) return;
                  final navegador = Navigator.of(context);
                  await context.read<AlacenaProvider>().eliminarProducto(p);
                  navegador.pop();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(p.nombre, style: const TextStyle(shadows: [Shadow(blurRadius: 8)])),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ProductoImagen(
                    ruta: p.imagen,
                    icono: p.categoriaIcono,
                    width: double.infinity,
                    height: double.infinity,
                    radius: 0,
                    heroTag: widget.heroTag,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final e in p.estatus) EstatusChip(e)]),
                  if (p.descripcion != null) ...[
                    const SizedBox(height: 10),
                    Text(p.descripcion!, style: t.bodyLarge),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Dato(titulo: 'Stock', valor: '${p.stock} ${p.unidad}'),
                      _Dato(titulo: 'Mínimo', valor: '${p.stockMinimo} ${p.unidad}'),
                      _Dato(
                        titulo: 'Caduca',
                        valor: p.proximaCaducidad == null ? '—' : Fechas.relativa(p.proximaCaducidad!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${p.categoriaIcono} ${p.categoriaNombre ?? ''}   ·   🏪 Última tienda: ${p.ultimaTiendaNombre ?? '—'}',
                    style: t.bodyMedium,
                  ),
                  Text(
                    p.notificar ? '🔔 Alarma el día de caducidad a las ${p.horaAlarma}' : '🔕 Sin alarma',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _consumir(p),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Consumir'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CompraFormScreen(producto: p)),
                          );
                          _cargar();
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Registrar compra'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _ejecutar(
                          () => context.read<AlacenaProvider>().agregarAlCarrito(p.id!),
                          '🛒 Agregado a la lista de compras',
                        ),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Al carrito'),
                      ),
                      if (p.estatus.contains(Estatus.caducado))
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: scheme.error),
                          onPressed: () => _ejecutar(
                            () => context.read<AlacenaProvider>().desecharCaducados(p.id!),
                            '🗑️ Lotes caducados desechados',
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Desechar caducados'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: EncabezadoSeccion(
              'Lotes (orden FEFO)',
              accion: IconButton(
                tooltip: 'Agregar lote',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => _editarLote(p),
              ),
            ),
          ),
          if (_lotes.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Sin existencia. Registra una compra o agrega un lote.'),
              ),
            )
          else
            SliverList.builder(
              itemCount: _lotes.length,
              itemBuilder: (context, i) {
                final l = _lotes[i];
                final cad = l.fechaCaducidad;
                final vencido = cad != null && Fechas.diasHasta(cad) < 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i == 0 ? scheme.primary : scheme.surfaceContainerHighest,
                    foregroundColor: i == 0 ? scheme.onPrimary : scheme.onSurface,
                    child: Text('${i + 1}'),
                  ),
                  title: Text('${l.cantidad} ${p.unidad}'
                      '${i == 0 ? '  ·  se consume primero' : ''}'),
                  subtitle: Text(
                    '${cad == null ? 'Sin caducidad' : 'Caduca ${Fechas.corta(cad)} (${Fechas.relativa(cad)})'}'
                    '\nIngresó ${Fechas.corta(l.fechaIngreso)}${l.tiendaNombre != null ? ' · ${l.tiendaNombre}' : ''}',
                    style: vencido ? TextStyle(color: scheme.error) : null,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'editar') {
                        _editarLote(p, l);
                      } else if (v == 'desechar') {
                        _ejecutar(() => context.read<AlacenaProvider>().desecharLote(l.id!), 'Lote desechado');
                      } else if (v == 'eliminar') {
                        final si = await confirmar(context, '¿Eliminar lote?',
                            'Se borrará el lote sin registrarlo como consumo ni desperdicio.');
                        if (si && context.mounted) {
                          _ejecutar(() => context.read<AlacenaProvider>().eliminarLote(l.id!), 'Lote eliminado');
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'desechar', child: Text('Desechar (desperdicio)')),
                      PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                    ],
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: EncabezadoSeccion('Tiendas donde se ha comprado')),
          if (_tiendas.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Aún no hay compras registradas.'),
              ),
            )
          else
            SliverList.builder(
              itemCount: _tiendas.length,
              itemBuilder: (context, i) {
                final th = _tiendas[i];
                final esMejor = precioMin != null && th.precioMinimo == precioMin && _tiendas.length > 1;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.storefront)),
                  title: Row(
                    children: [
                      Flexible(child: Text(th.nombre, overflow: TextOverflow.ellipsis)),
                      if (th.tiendaId == p.ultimaTiendaId) ...[
                        const SizedBox(width: 6),
                        const Chip(label: Text('Última'), visualDensity: VisualDensity.compact),
                      ],
                    ],
                  ),
                  subtitle: Text(
                      '${th.veces} compra(s) · ${th.unidades} ${p.unidad} · última ${Fechas.corta(th.ultimaFecha)}\n'
                      'Promedio ${Fechas.moneda(th.precioPromedio)} · mínimo ${Fechas.moneda(th.precioMinimo)}'),
                  isThreeLine: true,
                  trailing: esMejor ? const Tooltip(message: 'Mejor precio', child: Text('💲', style: TextStyle(fontSize: 22))) : null,
                );
              },
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 32),
              child: ExpansionTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('Historial de compras (${_compras.length})'),
                children: [
                  for (final c in _compras)
                    ListTile(
                      dense: true,
                      title: Text('${Fechas.corta(c.fechaCompra)} · ${c.tiendaNombre ?? ''}'),
                      subtitle: Text('${c.cantidad} ${p.unidad} × ${Fechas.moneda(c.precioUnitario)} = ${Fechas.moneda(c.total)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Eliminar registro',
                        onPressed: () async {
                          final si = await confirmar(context, '¿Eliminar registro de compra?',
                              'El lote que generó se conserva en la alacena.');
                          if (si && context.mounted) {
                            _ejecutar(() => context.read<AlacenaProvider>().eliminarCompra(c.id!), 'Registro eliminado');
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final String valor;
  const _Dato({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Text(valor, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(titulo, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
