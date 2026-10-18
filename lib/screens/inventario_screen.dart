import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/alacena_provider.dart';
import '../utils/estatus_ui.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'categorias_screen.dart';
import 'producto_detalle_screen.dart';
import 'producto_form_screen.dart';

/// Catálogo completo de artículos (CRUD) con búsqueda y filtro por categoría.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  String _busqueda = '';
  int? _categoriaId;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AlacenaProvider>();
    final q = _busqueda.trim().toLowerCase();
    final lista = prov.productos.where((p) {
      if (_categoriaId != null && p.categoriaId != _categoriaId) return false;
      if (q.isEmpty) return true;
      return p.nombre.toLowerCase().contains(q) || (p.descripcion ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (prov.categorias.isEmpty) {
            mostrarMensaje(context, 'Primero crea una categoría.', error: true);
            editarCategoriaDialog(context);
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductoFormScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Artículo'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            title: const Text('Alacena'),
            actions: const [CarritoBadgeButton(), SizedBox(width: 8)],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SearchBar(
                  hintText: 'Buscar artículo…',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Todas'),
                      selected: _categoriaId == null,
                      onSelected: (_) => setState(() => _categoriaId = null),
                    ),
                  ),
                  for (final c in prov.categorias)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('${c.icono} ${c.nombre}'),
                        selected: _categoriaId == c.id,
                        onSelected: (s) => setState(() => _categoriaId = s ? c.id : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (lista.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EstadoVacio(
                emoji: '🫙',
                titulo: prov.productos.isEmpty ? 'Tu alacena está vacía' : 'Sin resultados',
                mensaje: prov.productos.isEmpty
                    ? 'Registra tu primer artículo con el botón "+".'
                    : 'Prueba con otra búsqueda o categoría.',
              ),
            )
          else
            SliverList.separated(
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 88),
              itemBuilder: (context, i) {
                final p = lista[i];
                final e = p.estatusPrincipal;
                final tag = 'inv-${p.id}';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ProductoImagen(ruta: p.imagen, icono: p.categoriaIcono, width: 56, height: 56, heroTag: tag),
                  title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${p.stock} ${p.unidad}'
                    '${p.proximaCaducidad != null ? ' · caduca ${Fechas.corta(p.proximaCaducidad!)}' : ''}',
                  ),
                  trailing: Tooltip(
                    message: e.etiqueta,
                    child: Icon(e.icono, color: e.color),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductoDetalleScreen(productoId: p.id!, heroTag: tag),
                  )),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
