import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/estatus.dart';
import '../models/evento_calendario.dart';
import '../state/alacena_provider.dart';
import '../utils/estatus_ui.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'producto_detalle_screen.dart';

/// Modal a pantalla completa con los artículos con alerta de un día.
class DiaModal extends StatelessWidget {
  final DateTime dia;
  const DiaModal({super.key, required this.dia});

  @override
  Widget build(BuildContext context) {
    final clave = Fechas.clave(dia);
    final eventos = context.watch<AlacenaProvider>().eventosDe(clave);
    final scheme = Theme.of(context).colorScheme;
    final d = Fechas.diasHasta(clave);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(Fechas.larga(DateTime(dia.year, dia.month, dia.day))),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      eventos.isEmpty
                          ? 'Sin artículos con alerta este día.'
                          : '${eventos.length} artículo(s) · ${Fechas.relativa(clave)}'
                              '${d < 0 ? ' (fecha pasada)' : ''}',
                      style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (eventos.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EstadoVacio(
                emoji: '🗓️',
                titulo: 'Día tranquilo',
                mensaje: 'Ningún producto caduca ni tiene alerta de existencia este día.',
              ),
            )
          else
            SliverList.builder(
              itemCount: eventos.length,
              itemBuilder: (context, i) => _EventoCard(evento: eventos[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _EventoCard extends StatelessWidget {
  final EventoCalendario evento;
  const _EventoCard({required this.evento});

  @override
  Widget build(BuildContext context) {
    final p = evento.producto;
    final t = Theme.of(context).textTheme;
    final color = evento.principal.color;

    Widget dato(IconData icono, String texto) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(icono, size: 16, color: t.bodySmall?.color),
              const SizedBox(width: 6),
              Expanded(child: Text(texto, style: t.bodyMedium)),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductoImagen(ruta: p.imagen, icono: p.categoriaIcono, width: 84, height: 84),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final e in evento.tiposOrdenados)
                            e == Estatus.ok
                                ? const Chip(
                                    label: Text('Caduca este día'),
                                    visualDensity: VisualDensity.compact,
                                  )
                                : EstatusChip(e, compacto: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (evento.unidadesQueCaducan > 0)
              dato(Icons.event_busy, 'Caducan este día: ${evento.unidadesQueCaducan} ${p.unidad}'),
            dato(Icons.inventory_2_outlined, 'Stock total: ${p.stock} ${p.unidad} (mínimo ${p.stockMinimo})'),
            dato(Icons.category_outlined, '${p.categoriaIcono} ${p.categoriaNombre ?? ''}'),
            if (p.proximaCaducidad != null)
              dato(Icons.schedule, 'Próxima caducidad: ${Fechas.corta(p.proximaCaducidad!)}'),
            dato(Icons.storefront_outlined, 'Última tienda: ${p.ultimaTiendaNombre ?? 'Sin compras'}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductoDetalleScreen(productoId: p.id!),
                  )),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver detalle'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await context.read<AlacenaProvider>().agregarAlCarrito(p.id!);
                    if (context.mounted) mostrarMensaje(context, '🛒 ${p.nombre} agregado a la lista');
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Al carrito'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
