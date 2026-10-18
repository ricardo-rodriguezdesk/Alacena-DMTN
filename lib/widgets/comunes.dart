import 'dart:io';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/estatus.dart';
import '../screens/carrito_screen.dart';
import '../state/alacena_provider.dart';
import '../utils/estatus_ui.dart';

/// Imagen del artículo; si no tiene foto se muestra el emoji de su categoría.
class ProductoImagen extends StatelessWidget {
  final String? ruta;
  final String icono;
  final double width;
  final double height;
  final double radius;
  final Object? heroTag;

  const ProductoImagen({
    super.key,
    required this.ruta,
    required this.icono,
    this.width = 64,
    this.height = 64,
    this.radius = 14,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = height.isFinite ? height : 220.0;
    final placeholder = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(icono, style: TextStyle(fontSize: base * 0.45)),
    );

    Widget child = placeholder;
    final r = ruta;
    if (r != null && r.isNotEmpty && File(r).existsSync()) {
      child = Image.file(
        File(r),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    child = ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
    if (heroTag != null) child = Hero(tag: heroTag!, child: child);
    return child;
  }
}

/// Pastilla de color con icono para el estatus.
class EstatusChip extends StatelessWidget {
  final Estatus estatus;
  final bool compacto;
  const EstatusChip(this.estatus, {super.key, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final c = estatus.color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacto ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estatus.icono, size: 14, color: c),
          const SizedBox(width: 4),
          Text(estatus.etiqueta,
              style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Icono del carrito con contador (paquete badges).
class CarritoBadgeButton extends StatelessWidget {
  const CarritoBadgeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.select<AlacenaProvider, int>((p) => p.carritoCount);
    return IconButton(
      tooltip: 'Lista de compras',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CarritoScreen()),
      ),
      icon: badges.Badge(
        showBadge: n > 0,
        position: badges.BadgePosition.topEnd(top: -12, end: -10),
        badgeAnimation: badges.BadgeAnimation.scale(),
        badgeStyle: badges.BadgeStyle(badgeColor: const Color(0xFFD32F2F)),
        badgeContent: Text(
          '$n',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  const EstadoVacio({
    super.key,
    required this.emoji,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(titulo, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(mensaje, style: t.bodyMedium, textAlign: TextAlign.center),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}

class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final Widget? accion;
  const EncabezadoSeccion(this.titulo, {super.key, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFD32F2F) : null,
    ));
}

Future<bool> confirmar(BuildContext context, String titulo, String mensaje,
    {String accion = 'Eliminar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(accion)),
      ],
    ),
  );
  return r ?? false;
}

/// Selector desplegable con validación dentro de un Form. Se basa en
/// DropdownButton (API estable) para que el valor siempre refleje el estado.
class CampoSelector<T> extends StatelessWidget {
  final T? valor;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final String? Function(T? valor)? validator;

  const CampoSelector({
    super.key,
    required this.valor,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator: (_) => validator?.call(valor),
      builder: (estado) => InputDecorator(
        decoration: decoration.copyWith(errorText: estado.errorText),
        isEmpty: valor == null && !items.any((i) => i.value == null),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: valor,
            isExpanded: true,
            isDense: true,
            items: items,
            onChanged: (v) {
              onChanged(v);
              estado.didChange(v);
            },
          ),
        ),
      ),
    );
  }
}
