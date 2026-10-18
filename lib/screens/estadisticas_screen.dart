import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/estadisticas_repository.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';

/// Funcionalidad extra: gasto por tienda y control de desperdicio.
class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Se vuelve a consultar cada vez que cambian los datos.
    context.watch<AlacenaProvider>();
    return Scaffold(
      body: FutureBuilder<Estadisticas>(
        future: EstadisticasRepository().cargar(),
        builder: (context, snap) {
          return CustomScrollView(
            slivers: [
              const SliverAppBar.medium(title: Text('Estadísticas')),
              if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EstadoVacio(emoji: '⚠️', titulo: 'Error', mensaje: '${snap.error}'),
                )
              else if (!snap.hasData)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else
                ..._contenido(context, snap.data!),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, Estadisticas e) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final maxGasto = e.gastoPorTienda.isEmpty
        ? 1.0
        : e.gastoPorTienda.map((g) => g.gasto).reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    Widget tarjeta(String emoji, String valor, String titulo) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                FittedBox(child: Text(valor, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                Text(titulo, style: t.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        );

    final desperdicio = e.porcentajeDesperdicio;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            tarjeta('🫙', '${e.productos}', 'Artículos registrados'),
            tarjeta('📦', '${e.unidades}', 'Unidades en la alacena'),
            tarjeta('💰', Fechas.moneda(e.valorInventario), 'Valor estimado del inventario'),
            tarjeta('🧾', Fechas.moneda(e.gasto30), 'Gastado en 30 días'),
          ],
        ),
      ),
      const SliverToBoxAdapter(child: EncabezadoSeccion('Desperdicio (últimos 30 días)')),
      SliverToBoxAdapter(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(desperdicio * 100).toStringAsFixed(0)} % de lo que salió de la alacena se desechó',
                    style: t.titleSmall),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: desperdicio,
                    minHeight: 14,
                    color: desperdicio > 0.25 ? scheme.error : scheme.primary,
                    backgroundColor: scheme.primaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text('🍽️ Consumido: ${e.consumidas30}    🗑️ Desechado: ${e.desechadas30}'),
                if (e.masDesechados.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text('Lo que más se echa a perder', style: t.titleSmall),
                  for (final d in e.masDesechados)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${d.nombre}: ${d.cantidad}'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: EncabezadoSeccion('Gasto por tienda')),
      if (e.gastoPorTienda.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(16), child: Text('Aún no hay compras.')),
        )
      else
        SliverList.builder(
          itemCount: e.gastoPorTienda.length,
          itemBuilder: (context, i) {
            final g = e.gastoPorTienda[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('🏪 ${g.tienda} (${g.compras})')),
                      Text(Fechas.moneda(g.gasto), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: g.gasto / maxGasto, minHeight: 10),
                  ),
                ],
              ),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}
