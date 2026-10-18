import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/categoria.dart';
import '../models/tienda.dart';

/// Error de regla de negocio / integridad con mensaje para el usuario.
class ReglaException implements Exception {
  final String mensaje;
  const ReglaException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// CRUD de categorías y tiendas.
class CatalogoRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------------- Categorías ----------------

  Future<List<Categoria>> categorias() async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM producto p WHERE p.categoria_id = c.id) AS total_productos
      FROM categoria c ORDER BY c.nombre COLLATE NOCASE''');
    return r.map(Categoria.fromMap).toList();
  }

  Future<void> guardarCategoria(Categoria c) async {
    final db = await _db;
    try {
      if (c.id == null) {
        await db.insert('categoria', c.toMap());
      } else {
        await db.update('categoria', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
      }
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ReglaException('Ya existe una categoría llamada "${c.nombre.trim()}".');
      }
      rethrow;
    }
  }

  Future<void> eliminarCategoria(int id) async {
    final db = await _db;
    final n = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM producto WHERE categoria_id = ?', [id])) ??
        0;
    if (n > 0) {
      throw ReglaException(
          'No se puede eliminar: la categoría tiene $n producto(s). Muévelos o elimínalos primero.');
    }
    await db.delete('categoria', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Tiendas ----------------

  Future<List<Tienda>> tiendas() async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT t.*,
             (SELECT COUNT(*) FROM historial_compras h WHERE h.tienda_id = t.id) AS total_compras,
             (SELECT COALESCE(SUM(h.cantidad * h.precio_unitario), 0)
                FROM historial_compras h WHERE h.tienda_id = t.id) AS total_gastado
      FROM tienda t ORDER BY t.nombre COLLATE NOCASE''');
    return r.map(Tienda.fromMap).toList();
  }

  Future<int> guardarTienda(Tienda t) async {
    final db = await _db;
    try {
      if (t.id == null) return await db.insert('tienda', t.toMap());
      await db.update('tienda', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
      return t.id!;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ReglaException('Ya existe una tienda llamada "${t.nombre.trim()}".');
      }
      rethrow;
    }
  }

  Future<void> eliminarTienda(int id) async {
    final db = await _db;
    final n = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM historial_compras WHERE tienda_id = ?', [id])) ??
        0;
    if (n > 0) {
      throw ReglaException(
          'No se puede eliminar: la tienda tiene $n compra(s) en el historial (trazabilidad).');
    }
    await db.delete('tienda', where: 'id = ?', whereArgs: [id]);
  }
}
