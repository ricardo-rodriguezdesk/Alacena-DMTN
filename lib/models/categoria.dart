class Categoria {
  final int? id;
  final String nombre;
  final String icono;
  final int totalProductos;

  const Categoria({
    this.id,
    required this.nombre,
    this.icono = '📦',
    this.totalProductos = 0,
  });

  factory Categoria.fromMap(Map<String, Object?> m) => Categoria(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        icono: (m['icono'] as String?) ?? '📦',
        totalProductos: (m['total_productos'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre.trim(),
        'icono': icono,
      };
}
