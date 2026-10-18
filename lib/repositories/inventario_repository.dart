import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/compra.dart';
import '../models/evento_calendario.dart';
import '../models/lote.dart';
import '../utils/fechas.dart';
import 'catalogo_repository.dart';

/// Lotes, consumo con criterio FEFO e Historial_Compras.
class InventarioRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Orden FEFO: primero la caducidad más próxima; los lotes sin fecha de
  /// caducidad van al final; en empate, el que entró primero.
  static const ordenFefo =
      'CASE WHEN l.fecha_caducidad IS NULL THEN 1 ELSE 0 END, l.fecha_caducidad ASC, l.fecha_ingreso ASC, l.id ASC';

  Future<List<Lote>> lotesActivos(int productoId) async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT l.*, t.nombre AS tienda_nombre
      FROM lote l
      LEFT JOIN historial_compras h ON h.id = l.compra_id
      LEFT JOIN tienda t ON t.id = h.tienda_id
      WHERE l.producto_id = ? AND l.cantidad > 0
      ORDER BY $ordenFefo''', [productoId]);
    return r.map(Lote.fromMap).toList();
  }

  Future<List<LoteCaducidad>> lotesConCaducidad() async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT l.id, l.producto_id, l.cantidad, l.fecha_caducidad
      FROM lote l
      WHERE l.cantidad > 0 AND l.fecha_caducidad IS NOT NULL
      ORDER BY l.fecha_caducidad''');
    return r.map(LoteCaducidad.fromMap).toList();
  }

  Future<void> guardarLote(Lote l) async {
    final db = await _db;
    if (l.id == null) {
      await db.insert('lote', l.toMap()..remove('id'));
    } else {
      await db.update('lote', {'cantidad': l.cantidad, 'fecha_caducidad': l.fechaCaducidad},
          where: 'id = ?', whereArgs: [l.id]);
    }
  }

  Future<void> eliminarLote(int id) async {
    final db = await _db;
    await db.delete('lote', where: 'id = ?', whereArgs: [id]);
  }

  /// Regla FEFO: descuenta [cantidad] unidades empezando por el lote con la
  /// fecha de caducidad más próxima. Todo ocurre en una transacción.
  Future<void> consumir(int productoId, int cantidad, {String motivo = 'consumo'}) async {
    if (cantidad <= 0) throw const ReglaException('La cantidad debe ser mayor a cero.');
    final db = await _db;
    await db.transaction((txn) async {
      final lotes = await txn.rawQuery('''
        SELECT l.id, l.cantidad FROM lote l
        WHERE l.producto_id = ? AND l.cantidad > 0
        ORDER BY $ordenFefo''', [productoId]);
      final disponible = lotes.fold<int>(0, (s, l) => s + (l['cantidad'] as num).toInt());
      if (cantidad > disponible) {
        throw ReglaException('Solo hay $disponible unidad(es) disponibles.');
      }
      var restante = cantidad;
      for (final l in lotes) {
        if (restante == 0) break;
        final id = l['id'] as int;
        final hay = (l['cantidad'] as num).toInt();
        final tomar = math.min(hay, restante);
        await txn.update('lote', {'cantidad': hay - tomar}, where: 'id = ?', whereArgs: [id]);
        await txn.insert('consumo', {
          'producto_id': productoId,
          'lote_id': id,
          'cantidad': tomar,
          'motivo': motivo,
          'fecha': Fechas.hoyClave(),
        });
        restante -= tomar;
      }
    });
  }

  /// Desecha (pone en 0 y registra como desperdicio) un lote completo.
  Future<void> desecharLote(int loteId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final r = await txn.query('lote', where: 'id = ?', whereArgs: [loteId]);
      if (r.isEmpty) return;
      final hay = (r.first['cantidad'] as num).toInt();
      if (hay <= 0) return;
      await txn.update('lote', {'cantidad': 0}, where: 'id = ?', whereArgs: [loteId]);
      await txn.insert('consumo', {
        'producto_id': r.first['producto_id'],
        'lote_id': loteId,
        'cantidad': hay,
        'motivo': 'desecho',
        'fecha': Fechas.hoyClave(),
      });
    });
  }

  /// Desecha todos los lotes ya caducados de un producto.
  Future<int> desecharCaducados(int productoId) async {
    final db = await _db;
    final r = await db.query('lote',
        columns: ['id'],
        where: 'producto_id = ? AND cantidad > 0 AND fecha_caducidad IS NOT NULL AND fecha_caducidad < ?',
        whereArgs: [productoId, Fechas.hoyClave()]);
    for (final l in r) {
      await desecharLote(l['id'] as int);
    }
    return r.length;
  }

  /// Registra una compra en Historial_Compras y crea el lote correspondiente.
  /// El trigger `trg_compra_ultima_tienda` actualiza producto.ultima_tienda_id.
  Future<void> registrarCompra(Compra c, {String? fechaCaducidad}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final compraId = await txn.insert('historial_compras', c.toMap()..remove('id'));
      await txn.insert('lote', {
        'producto_id': c.productoId,
        'compra_id': compraId,
        'cantidad': c.cantidad,
        'fecha_caducidad': fechaCaducidad,
        'fecha_ingreso': c.fechaCompra,
      });
    });
  }

  Future<List<Compra>> comprasDeProducto(int productoId) async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT h.*, t.nombre AS tienda_nombre
      FROM historial_compras h JOIN tienda t ON t.id = h.tienda_id
      WHERE h.producto_id = ?
      ORDER BY h.fecha_compra DESC, h.id DESC''', [productoId]);
    return r.map(Compra.fromMap).toList();
  }

  /// Borra un registro del historial. Los lotes que generó se conservan
  /// (compra_id pasa a NULL) y el trigger recalcula la última tienda.
  Future<void> eliminarCompra(int compraId) async {
    final db = await _db;
    await db.delete('historial_compras', where: 'id = ?', whereArgs: [compraId]);
  }
}
