import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../repositories/catalogo_repository.dart';
import '../state/alacena_provider.dart';
import '../widgets/comunes.dart';

const _emojis = ['🥛', '🧀', '🥕', '🍎', '🥩', '🐟', '🥫', '🍝', '🍞', '🥚', '🧃', '☕', '🍪', '🧼', '🧻', '🧊', '🌶️', '🧂', '🍫', '📦'];

/// Diálogo para crear/editar una categoría.
Future<void> editarCategoriaDialog(BuildContext context, [Categoria? categoria]) async {
  final nombre = TextEditingController(text: categoria?.nombre ?? '');
  var icono = categoria?.icono ?? '📦';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(categoria == null ? 'Nueva categoría' : 'Editar categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                autofocus: categoria == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final e in _emojis)
                    ChoiceChip(
                      label: Text(e, style: const TextStyle(fontSize: 20)),
                      selected: icono == e,
                      showCheckmark: false,
                      onSelected: (_) => setD(() => icono = e),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  if (nombre.text.trim().isEmpty) {
    mostrarMensaje(context, 'El nombre de la categoría es obligatorio.', error: true);
    return;
  }
  try {
    await context.read<AlacenaProvider>().guardarCategoria(
          Categoria(id: categoria?.id, nombre: nombre.text, icono: icono),
        );
  } on ReglaException catch (e) {
    if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
  }
}

class CategoriasScreen extends StatelessWidget {
  const CategoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<AlacenaProvider>().categorias;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarCategoriaDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Categoría'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Categorías')),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: categorias.length,
              itemBuilder: (context, i) {
                final c = categorias[i];
                return Card(
                  color: scheme.secondaryContainer,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => editarCategoriaDialog(context, c),
                    onLongPress: () async {
                      final si = await confirmar(context, '¿Eliminar ${c.nombre}?',
                          'Solo se puede eliminar si no tiene productos.');
                      if (!si || !context.mounted) return;
                      try {
                        await context.read<AlacenaProvider>().eliminarCategoria(c.id!);
                      } on ReglaException catch (e) {
                        if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.icono, style: const TextStyle(fontSize: 44)),
                          const SizedBox(height: 6),
                          Text(c.nombre,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${c.totalProductos} artículo(s)', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: Text('Toca para editar · mantén presionado para eliminar', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
