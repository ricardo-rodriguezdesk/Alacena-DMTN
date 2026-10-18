import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../screens/producto_detalle_screen.dart';
import '../state/alacena_provider.dart';
import '../utils/estatus_ui.dart';
import '../utils/fechas.dart';
import 'comunes.dart';

/// Tarjeta del listado principal: imagen, estatus por color/icono y botón
/// para agregar al carrito.
class ProductoAlertaCard extends StatelessWidget {
  final Producto producto;
  final String heroPrefijo;

  const ProductoAlertaCard({super.key, required this.producto, this.heroPrefijo = 'alerta'});

  Future<void> _alCarrito(BuildContext context) async {
    final nuevo = await context.read<AlacenaProvider>().agregarAlCarrito(producto.id!);
    if (!context.mounted) return;
    mostrarMensaje(
        context, nuevo ? '🛒 ${producto.nombre} agregado a la lista' : '🛒 +1 ${producto.nombre} en la lista');
  }

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final principal = p.estatusPrincipal;
    final t = Theme.of(context).textTheme;
    final tag = '$heroPrefijo-${p.id}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductoDetalleScreen(productoId: p.id!, heroTag: tag),
        )),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: principal.color, width: 6)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              ProductoImagen(ruta: p.imagen, icono: p.categoriaIcono, width: 68, height: 68, heroTag: tag),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${p.categoriaIcono} ${p.categoriaNombre ?? ''} · Stock: ${p.stock} ${p.unidad}',
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.proximaCaducidad != null)
                      Text(
                        'Caduca: ${Fechas.relativa(p.proximaCaducidad!)} (${Fechas.corta(p.proximaCaducidad!)})',
                        style: t.bodySmall?.copyWith(color: principal.color, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [for (final e in p.estatus) EstatusChip(e, compacto: true)],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Agregar al carrito',
                onPressed: () => _alCarrito(context),
                icon: Icon(p.enCarrito ? Icons.shopping_cart : Icons.add_shopping_cart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
