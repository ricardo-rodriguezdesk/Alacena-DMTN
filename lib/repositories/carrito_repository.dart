import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/carrito_item.dart';

class CarritoRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<CarritoItem>> items() async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT ca.*, p.nombre AS producto_nombre, p.imagen, p.unidad,
             c.icono AS categoria_icono, t.nombre AS ultima_tienda_nombre,
             (SELECT h.precio_unitario FROM historial_compras h
               WHERE h.producto_id = p.id
               ORDER BY h.fecha_compra DESC, h.id DESC LIMIT 1) AS precio_ref
      FROM carrito ca
      JOIN producto p ON p.id = ca.producto_id
      JOIN categoria c ON c.id = p.categoria_id
      LEFT JOIN tienda t ON t.id = p.ultima_tienda_id
      ORDER BY ca.id DESC''');
    return r.map(CarritoItem.fromMap).toList();
  }

  /// Agrega el producto al carrito; si ya estaba, suma la cantidad.
  /// Devuelve true si era nuevo.
  Future<bool> agregar(int productoId, {int cantidad = 1}) async {
    final db = await _db;
    return db.transaction((txn) async {
      final r = await txn.query('carrito',
          columns: ['id', 'cantidad'], where: 'producto_id = ?', whereArgs: [productoId]);
      if (r.isEmpty) {
        await txn.insert('carrito', {'producto_id': productoId, 'cantidad': cantidad});
        return true;
      }
      await txn.update('carrito', {'cantidad': (r.first['cantidad'] as num).toInt() + cantidad},
          where: 'id = ?', whereArgs: [r.first['id']]);
      return false;
    });
  }

  Future<void> cambiarCantidad(int id, int cantidad) async {
    final db = await _db;
    if (cantidad <= 0) {
      await eliminar(id);
    } else {
      await db.update('carrito', {'cantidad': cantidad}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('carrito', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> vaciar() async {
    final db = await _db;
    await db.delete('carrito');
  }
}
