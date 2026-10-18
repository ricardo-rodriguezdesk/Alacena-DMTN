import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/estatus.dart';
import '../state/alacena_provider.dart';
import '../utils/estatus_ui.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import '../widgets/producto_card.dart';

/// Pantalla principal: artículos próximos a caducar o por agotarse.
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  Estatus? _filtro;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AlacenaProvider>();
    final todas = prov.alertas;
    final lista = _filtro == null ? todas : todas.where((p) => p.estatus.contains(_filtro)).toList();
    int cuenta(Estatus e) => todas.where((p) => p.estatus.contains(e)).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: prov.cargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              title: const Text('Mi alacena'),
              actions: const [CarritoBadgeButton(), SizedBox(width: 8)],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  Fechas.larga(DateTime.now()),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('Todas (${todas.length})'),
                        selected: _filtro == null,
                        onSelected: (_) => setState(() => _filtro = null),
                      ),
                    ),
                    for (final e in [Estatus.caducado, Estatus.agotado, Estatus.porCaducar, Estatus.porAgotarse])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(e.icono, color: e.color, size: 18),
                          label: Text('${e.etiqueta} (${cuenta(e)})'),
                          selected: _filtro == e,
                          selectedColor: e.color.withValues(alpha: 0.18),
                          showCheckmark: false,
                          onSelected: (s) => setState(() => _filtro = s ? e : null),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (prov.cargando)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (prov.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EstadoVacio(emoji: '⚠️', titulo: 'Ocurrió un error', mensaje: prov.error!),
              )
            else if (lista.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EstadoVacio(
                  emoji: '🎉',
                  titulo: 'Todo en orden',
                  mensaje: 'No hay artículos caducados, por caducar ni por agotarse.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) => ProductoAlertaCard(producto: lista[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
