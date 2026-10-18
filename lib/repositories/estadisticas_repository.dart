import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../utils/fechas.dart';

class GastoTienda {
  final String tienda;
  final double gasto;
  final int compras;
  const GastoTienda(this.tienda, this.gasto, this.compras);
}

class ProductoCantidad {
  final String nombre;
  final int cantidad;
  const ProductoCantidad(this.nombre, this.cantidad);
}

class Estadisticas {
  final int productos;
  final int unidades;
  final double valorInventario;
  final int consumidas30;
  final int desechadas30;
  final double gasto30;
  final List<GastoTienda> gastoPorTienda;
  final List<ProductoCantidad> masDesechados;

  const Estadisticas({
    required this.productos,
    required this.unidades,
    required this.valorInventario,
    required this.consumidas30,
    required this.desechadas30,
    required this.gasto30,
    required this.gastoPorTienda,
    required this.masDesechados,
  });

  double get porcentajeDesperdicio {
    final total = consumidas30 + desechadas30;
    return total == 0 ? 0 : desechadas30 / total;
  }
}

class EstadisticasRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<Estadisticas> cargar() async {
    final db = await _db;
    final desde = Fechas.masDias(-30);

    final productos = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM producto')) ?? 0;
    final unidades = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COALESCE(SUM(cantidad), 0) FROM lote WHERE cantidad > 0')) ??
        0;

    final valor = await db.rawQuery('''
      SELECT COALESCE(SUM(l.cantidad * COALESCE((
        SELECT h.precio_unitario FROM historial_compras h
        WHERE h.producto_id = l.producto_id
        ORDER BY h.fecha_compra DESC, h.id DESC LIMIT 1), 0)), 0) AS valor
      FROM lote l WHERE l.cantidad > 0''');

    final consumo = await db.rawQuery(
        'SELECT motivo, SUM(cantidad) AS total FROM consumo WHERE fecha >= ? GROUP BY motivo', [desde]);
    var consumidas = 0, desechadas = 0;
    for (final r in consumo) {
      final t = (r['total'] as num?)?.toInt() ?? 0;
      if (r['motivo'] == 'consumo') {
        consumidas = t;
      } else {
        desechadas = t;
      }
    }

    final gasto30 = await db.rawQuery(
        'SELECT COALESCE(SUM(cantidad * precio_unitario), 0) AS g FROM historial_compras WHERE fecha_compra >= ?',
        [desde]);

    final porTienda = await db.rawQuery('''
      SELECT t.nombre, SUM(h.cantidad * h.precio_unitario) AS gasto, COUNT(h.id) AS compras
      FROM historial_compras h JOIN tienda t ON t.id = h.tienda_id
      GROUP BY t.id, t.nombre ORDER BY gasto DESC''');

    final desechados = await db.rawQuery('''
      SELECT p.nombre, SUM(c.cantidad) AS total
      FROM consumo c JOIN producto p ON p.id = c.producto_id
      WHERE c.motivo = 'desecho'
      GROUP BY p.id, p.nombre ORDER BY total DESC LIMIT 5''');

    return Estadisticas(
      productos: productos,
      unidades: unidades,
      valorInventario: (valor.first['valor'] as num?)?.toDouble() ?? 0,
      consumidas30: consumidas,
      desechadas30: desechadas,
      gasto30: (gasto30.first['g'] as num?)?.toDouble() ?? 0,
      gastoPorTienda: porTienda
          .map((r) => GastoTienda(r['nombre'] as String, (r['gasto'] as num?)?.toDouble() ?? 0,
              (r['compras'] as num?)?.toInt() ?? 0))
          .toList(),
      masDesechados: desechados
          .map((r) => ProductoCantidad(r['nombre'] as String, (r['total'] as num?)?.toInt() ?? 0))
          .toList(),
    );
  }
}
