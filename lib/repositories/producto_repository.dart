import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/producto.dart';
import '../models/tienda.dart';

class ProductoRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Stock total = suma de `cantidad` de los lotes activos (cantidad > 0).
  /// Próxima caducidad = la fecha más cercana entre los lotes activos.
  static const _select = '''
    SELECT p.*,
           c.nombre AS categoria_nombre,
           c.icono  AS categoria_icono,
           t.nombre AS ultima_tienda_nombre,
           COALESCE((SELECT SUM(l.cantidad) FROM lote l
                     WHERE l.producto_id = p.id AND l.cantidad > 0), 0) AS stock,
           (SELECT MIN(l.fecha_caducidad) FROM lote l
             WHERE l.producto_id = p.id AND l.cantidad > 0
               AND l.fecha_caducidad IS NOT NULL) AS proxima_caducidad,
           (SELECT COUNT(*) FROM carrito ca WHERE ca.producto_id = p.id) AS en_carrito
    FROM producto p
    JOIN categoria c ON c.id = p.categoria_id
    LEFT JOIN tienda t ON t.id = p.ultima_tienda_id''';

  Future<List<Producto>> todos() async {
    final db = await _db;
    final r = await db.rawQuery('$_select ORDER BY p.nombre COLLATE NOCASE');
    return r.map(Producto.fromMap).toList();
  }

  Future<int> insertar(Producto p) async {
    final db = await _db;
    return db.insert('producto', p.toMap()..remove('id'));
  }

  Future<void> actualizar(Producto p) async {
    final db = await _db;
    await db.update('producto', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  /// Borra el producto. Por ON DELETE CASCADE se eliminan sus lotes,
  /// historial de compras, consumos y su renglón del carrito.
  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('producto', where: 'id = ?', whereArgs: [id]);
  }

  /// Histórico global: todas las tiendas donde se ha comprado el producto.
  Future<List<TiendaHistorial>> tiendasDondeSeCompro(int productoId) async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT t.id AS tienda_id, t.nombre,
             COUNT(h.id)            AS veces,
             SUM(h.cantidad)        AS unidades,
             MAX(h.fecha_compra)    AS ultima_fecha,
             AVG(h.precio_unitario) AS precio_promedio,
             MIN(h.precio_unitario) AS precio_minimo
      FROM historial_compras h
      JOIN tienda t ON t.id = h.tienda_id
      WHERE h.producto_id = ?
      GROUP BY t.id, t.nombre
      ORDER BY ultima_fecha DESC''', [productoId]);
    return r.map(TiendaHistorial.fromMap).toList();
  }
}
