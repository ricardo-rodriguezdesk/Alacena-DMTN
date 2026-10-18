import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tienda.dart';
import '../repositories/catalogo_repository.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';

/// Diálogo para crear/editar una tienda. Devuelve el id guardado.
Future<int?> editarTiendaDialog(BuildContext context, [Tienda? tienda]) async {
  final nombre = TextEditingController(text: tienda?.nombre ?? '');
  final direccion = TextEditingController(text: tienda?.direccion ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tienda == null ? 'Nueva tienda' : 'Editar tienda'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: direccion,
            decoration: const InputDecoration(labelText: 'Dirección / sucursal'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;
  if (nombre.text.trim().isEmpty) {
    mostrarMensaje(context, 'El nombre de la tienda es obligatorio.', error: true);
    return null;
  }
  try {
    return await context.read<AlacenaProvider>().guardarTienda(
          Tienda(id: tienda?.id, nombre: nombre.text, direccion: direccion.text),
        );
  } on ReglaException catch (e) {
    if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
  }
  return null;
}

class TiendasScreen extends StatelessWidget {
  const TiendasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiendas = context.watch<AlacenaProvider>().tiendas;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarTiendaDialog(context),
        icon: const Icon(Icons.add_business),
        label: const Text('Tienda'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Tiendas')),
          if (tiendas.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EstadoVacio(emoji: '🏪', titulo: 'Sin tiendas', mensaje: 'Agrega dónde haces tus compras.'),
            )
          else
            SliverList.builder(
              itemCount: tiendas.length,
              itemBuilder: (context, i) {
                final t = tiendas[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.storefront)),
                    title: Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text([
                      if (t.direccion != null) t.direccion!,
                      '${t.totalCompras} compra(s) · ${Fechas.moneda(t.totalGastado)}',
                    ].join('\n')),
                    isThreeLine: t.direccion != null,
                    onTap: () => editarTiendaDialog(context, t),
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final si = await confirmar(context, '¿Eliminar ${t.nombre}?',
                            'Solo se puede eliminar si no tiene compras en el historial.');
                        if (!si || !context.mounted) return;
                        try {
                          await context.read<AlacenaProvider>().eliminarTienda(t.id!);
                        } on ReglaException catch (e) {
                          if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
