class CarritoItem {
  final int id;
  final int productoId;
  final int cantidad;
  final String productoNombre;
  final String? imagen;
  final String unidad;
  final String categoriaIcono;
  final String? ultimaTiendaNombre;
  final double? precioReferencia;

  const CarritoItem({
    required this.id,
    required this.productoId,
    required this.cantidad,
    required this.productoNombre,
    this.imagen,
    required this.unidad,
    required this.categoriaIcono,
    this.ultimaTiendaNombre,
    this.precioReferencia,
  });

  factory CarritoItem.fromMap(Map<String, Object?> m) => CarritoItem(
        id: m['id'] as int,
        productoId: m['producto_id'] as int,
        cantidad: (m['cantidad'] as num).toInt(),
        productoNombre: m['producto_nombre'] as String,
        imagen: m['imagen'] as String?,
        unidad: (m['unidad'] as String?) ?? 'pza',
        categoriaIcono: (m['categoria_icono'] as String?) ?? '📦',
        ultimaTiendaNombre: m['ultima_tienda_nombre'] as String?,
        precioReferencia: (m['precio_ref'] as num?)?.toDouble(),
      );
}
