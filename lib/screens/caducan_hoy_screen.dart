import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'producto_detalle_screen.dart';

/// Pantalla que abre la alarma local: productos que caducan en [fecha].
class CaducanHoyScreen extends StatelessWidget {
  final String? fecha;
  const CaducanHoyScreen({super.key, this.fecha});

  @override
  Widget build(BuildContext context) {
    final dia = fecha ?? Fechas.hoyClave();
    final esHoy = dia == Fechas.hoyClave();
    final prov = context.watch<AlacenaProvider>();
    final lotes = prov.lotesQueCaducan(dia);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(esHoy ? 'Caducan hoy' : 'Caducan el ${Fechas.corta(dia)}'),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lotes.isEmpty ? scheme.primaryContainer : scheme.errorContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(lotes.isEmpty ? '✅' : '⏰', style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lotes.isEmpty
                          ? 'Ningún producto caduca este día.'
                          : '${lotes.length} lote(s) caducan ${esHoy ? 'hoy' : 'este día'}. '
                              'Consúmelos primero o regístralos como desperdicio.',
                      style: TextStyle(
                        color: lotes.isEmpty ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: lotes.length,
            itemBuilder: (context, i) {
              final (p, l) = lotes[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ProductoImagen(ruta: p.imagen, icono: p.categoriaIcono, width: 60, height: 60),
                  title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${l.cantidad} ${p.unidad} · ${p.categoriaNombre ?? ''}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProductoDetalleScreen(productoId: p.id!)),
                  ),
                  trailing: IconButton(
                    tooltip: 'Desechar lote',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () async {
                      final si = await confirmar(context, '¿Desechar este lote?',
                          'Se registrarán ${l.cantidad} ${p.unidad} como desperdicio.',
                          accion: 'Desechar');
                      if (si && context.mounted) {
                        await context.read<AlacenaProvider>().desecharLote(l.loteId);
                      }
                    },
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
