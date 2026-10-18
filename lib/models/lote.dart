class Lote {
  final int? id;
  final int productoId;
  final int? compraId;
  final int cantidad;
  final String? fechaCaducidad;
  final String fechaIngreso;
  final String? tiendaNombre;

  const Lote({
    this.id,
    required this.productoId,
    this.compraId,
    required this.cantidad,
    this.fechaCaducidad,
    required this.fechaIngreso,
    this.tiendaNombre,
  });

  factory Lote.fromMap(Map<String, Object?> m) => Lote(
        id: m['id'] as int?,
        productoId: m['producto_id'] as int,
        compraId: m['compra_id'] as int?,
        cantidad: (m['cantidad'] as num).toInt(),
        fechaCaducidad: m['fecha_caducidad'] as String?,
        fechaIngreso: m['fecha_ingreso'] as String,
        tiendaNombre: m['tienda_nombre'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'producto_id': productoId,
        'compra_id': compraId,
        'cantidad': cantidad,
        'fecha_caducidad': fechaCaducidad,
        'fecha_ingreso': fechaIngreso,
      };
}
