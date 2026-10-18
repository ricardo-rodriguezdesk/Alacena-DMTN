/// Registro de Historial_Compras.
class Compra {
  final int? id;
  final int productoId;
  final int tiendaId;
  final int cantidad;
  final double precioUnitario;
  final String fechaCompra;
  final String? tiendaNombre;

  const Compra({
    this.id,
    required this.productoId,
    required this.tiendaId,
    required this.cantidad,
    required this.precioUnitario,
    required this.fechaCompra,
    this.tiendaNombre,
  });

  double get total => cantidad * precioUnitario;

  factory Compra.fromMap(Map<String, Object?> m) => Compra(
        id: m['id'] as int?,
        productoId: m['producto_id'] as int,
        tiendaId: m['tienda_id'] as int,
        cantidad: (m['cantidad'] as num).toInt(),
        precioUnitario: (m['precio_unitario'] as num?)?.toDouble() ?? 0,
        fechaCompra: m['fecha_compra'] as String,
        tiendaNombre: m['tienda_nombre'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'producto_id': productoId,
        'tienda_id': tiendaId,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'fecha_compra': fechaCompra,
      };
}
