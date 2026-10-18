class Tienda {
  final int? id;
  final String nombre;
  final String? direccion;
  final int totalCompras;
  final double totalGastado;

  const Tienda({
    this.id,
    required this.nombre,
    this.direccion,
    this.totalCompras = 0,
    this.totalGastado = 0,
  });

  factory Tienda.fromMap(Map<String, Object?> m) => Tienda(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        direccion: m['direccion'] as String?,
        totalCompras: (m['total_compras'] as num?)?.toInt() ?? 0,
        totalGastado: (m['total_gastado'] as num?)?.toDouble() ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre.trim(),
        'direccion': (direccion == null || direccion!.trim().isEmpty) ? null : direccion!.trim(),
      };
}

/// Resumen de compras de un producto en una tienda (trazabilidad global).
class TiendaHistorial {
  final int tiendaId;
  final String nombre;
  final int veces;
  final int unidades;
  final String ultimaFecha;
  final double precioPromedio;
  final double precioMinimo;

  const TiendaHistorial({
    required this.tiendaId,
    required this.nombre,
    required this.veces,
    required this.unidades,
    required this.ultimaFecha,
    required this.precioPromedio,
    required this.precioMinimo,
  });

  factory TiendaHistorial.fromMap(Map<String, Object?> m) => TiendaHistorial(
        tiendaId: m['tienda_id'] as int,
        nombre: m['nombre'] as String,
        veces: (m['veces'] as num?)?.toInt() ?? 0,
        unidades: (m['unidades'] as num?)?.toInt() ?? 0,
        ultimaFecha: m['ultima_fecha'] as String,
        precioPromedio: (m['precio_promedio'] as num?)?.toDouble() ?? 0,
        precioMinimo: (m['precio_minimo'] as num?)?.toDouble() ?? 0,
      );
}
