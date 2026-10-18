import 'estatus.dart';
import 'producto.dart';

/// Un producto con alguna alerta en un día del calendario.
/// Si un producto tiene varios lotes que caducan el mismo día se agrupan
/// en un solo evento, así cada punto del calendario = un producto.
class EventoCalendario {
  final Producto producto;
  final Set<Estatus> tipos;
  int unidadesQueCaducan;

  EventoCalendario({
    required this.producto,
    required this.tipos,
    this.unidadesQueCaducan = 0,
  });

  Estatus get principal {
    final l = tipos.toList()..sort((a, b) => a.index.compareTo(b.index));
    return l.first;
  }

  List<Estatus> get tiposOrdenados => tipos.toList()..sort((a, b) => a.index.compareTo(b.index));
}

/// Lote con stock y fecha de caducidad (para calendario y alarmas).
class LoteCaducidad {
  final int loteId;
  final int productoId;
  final int cantidad;
  final String fechaCaducidad;

  const LoteCaducidad({
    required this.loteId,
    required this.productoId,
    required this.cantidad,
    required this.fechaCaducidad,
  });

  factory LoteCaducidad.fromMap(Map<String, Object?> m) => LoteCaducidad(
        loteId: m['id'] as int,
        productoId: m['producto_id'] as int,
        cantidad: (m['cantidad'] as num).toInt(),
        fechaCaducidad: m['fecha_caducidad'] as String,
      );
}
