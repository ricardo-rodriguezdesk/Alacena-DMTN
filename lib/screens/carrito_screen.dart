import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/carrito_item.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'compra_form_screen.dart';

/// Carrito / lista de compras.
class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  Future<void> _copiar(BuildContext context, List<CarritoItem> items) async {
    final texto = StringBuffer('🛒 Lista de compras\n');
    for (final i in items) {
      texto.writeln('• ${i.productoNombre} — ${i.cantidad} ${i.unidad}'
          '${i.ultimaTiendaNombre != null ? ' (${i.ultimaTiendaNombre})' : ''}');
    }
    await Clipboard.setData(ClipboardData(text: texto.toString()));
    if (context.mounted) mostrarMensaje(context, '📋 Lista copiada, pégala en WhatsApp o notas');
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AlacenaProvider>();
    final items = prov.carrito;
    final total = items.fold<double>(0, (s, i) => s + (i.precioReferencia ?? 0.0) * i.cantidad);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Lista de compras'),
            actions: [
              if (items.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Copiar lista',
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () => _copiar(context, items),
                ),
                IconButton(
                  tooltip: 'Vaciar',
                  icon: const Icon(Icons.remove_shopping_cart_outlined),
                  onPressed: () async {
                    final si = await confirmar(context, '¿Vaciar la lista?', 'Se quitarán todos los artículos.',
                        accion: 'Vaciar');
                    if (si && context.mounted) await context.read<AlacenaProvider>().vaciarCarrito();
                  },
                ),
              ],
            ],
          ),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EstadoVacio(
                emoji: '🛒',
                titulo: 'Tu lista está vacía',
                mensaje: 'Agrega artículos desde la pantalla principal con el botón del carrito.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Desliza a la izquierda para quitar · toca "Comprado" al adquirirlo',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _ItemCarrito(item: items[i]),
            ),
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Total estimado'),
                  subtitle: const Text('Según el último precio pagado'),
                  trailing: Text(Fechas.moneda(total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemCarrito extends StatelessWidget {
  final CarritoItem item;
  const _ItemCarrito({required this.item});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AlacenaProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('carrito-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) {
        prov.quitarDelCarrito(item.id);
        mostrarMensaje(context, '${item.productoNombre} quitado de la lista');
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ProductoImagen(ruta: item.imagen, icono: item.categoriaIcono, width: 56, height: 56),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productoNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      [
                        if (item.ultimaTiendaNombre != null) '🏪 ${item.ultimaTiendaNombre}',
                        if (item.precioReferencia != null) Fechas.moneda(item.precioReferencia!),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => prov.cambiarCantidadCarrito(item.id, item.cantidad - 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${item.cantidad} ${item.unidad}'),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => prov.cambiarCantidadCarrito(item.id, item.cantidad + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () {
                  final p = prov.productoPorId(item.productoId);
                  if (p == null) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CompraFormScreen(
                      producto: p,
                      cantidadInicial: item.cantidad,
                      carritoItemId: item.id,
                    ),
                  ));
                },
                child: const Text('Comprado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
