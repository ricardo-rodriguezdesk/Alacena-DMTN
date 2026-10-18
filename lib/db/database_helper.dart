import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/fechas.dart';

/// Capa de persistencia local (SQLite).
///
/// Integridad de dominio: NOT NULL, UNIQUE, CHECK (rangos, listas de valores,
/// formato de fechas 'yyyy-MM-dd' y hora 'HH:mm').
/// Integridad referencial: FOREIGN KEY con ON DELETE RESTRICT / CASCADE /
/// SET NULL según el caso, y `PRAGMA foreign_keys = ON` en cada conexión.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _nombreBD = 'alacena.db';
  static const _version = 1;

  Future<Database>? _db;

  Future<Database> get database => _db ??= _abrir();

  Future<Database> _abrir() async {
    final ruta = p.join(await getDatabasesPath(), _nombreBD);
    return openDatabase(
      ruta,
      version: _version,
      onConfigure: (db) async {
        // SQLite trae las llaves foráneas desactivadas por defecto.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _crearEsquema(db);
        await _datosIniciales(db);
      },
    );
  }

  static const _formatoFecha = "GLOB '[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]'";

  Future<void> _crearEsquema(Database db) async {
    final b = db.batch();

    b.execute('''
      CREATE TABLE categoria (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre  TEXT NOT NULL UNIQUE COLLATE NOCASE
                CHECK (length(trim(nombre)) BETWEEN 1 AND 40),
        icono   TEXT NOT NULL DEFAULT '📦'
      )''');

    b.execute('''
      CREATE TABLE tienda (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre     TEXT NOT NULL UNIQUE COLLATE NOCASE
                   CHECK (length(trim(nombre)) BETWEEN 1 AND 60),
        direccion  TEXT
      )''');

    b.execute('''
      CREATE TABLE producto (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre            TEXT NOT NULL CHECK (length(trim(nombre)) BETWEEN 1 AND 60),
        descripcion       TEXT,
        categoria_id      INTEGER NOT NULL
                          REFERENCES categoria(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        imagen            TEXT,
        unidad            TEXT NOT NULL DEFAULT 'pza'
                          CHECK (unidad IN ('pza','paquete','lata','botella','caja','bolsa','kg','g','L','ml')),
        stock_minimo      INTEGER NOT NULL DEFAULT 1 CHECK (stock_minimo >= 0),
        dias_aviso        INTEGER NOT NULL DEFAULT 3 CHECK (dias_aviso BETWEEN 0 AND 60),
        notificar         INTEGER NOT NULL DEFAULT 1 CHECK (notificar IN (0, 1)),
        hora_alarma       TEXT NOT NULL DEFAULT '09:00'
                          CHECK (hora_alarma GLOB '[0-2][0-9]:[0-5][0-9]'),
        ultima_tienda_id  INTEGER
                          REFERENCES tienda(id) ON UPDATE CASCADE ON DELETE SET NULL,
        creado_en         TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
      )''');

    b.execute('''
      CREATE TABLE historial_compras (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id      INTEGER NOT NULL REFERENCES producto(id) ON DELETE CASCADE,
        tienda_id        INTEGER NOT NULL REFERENCES tienda(id) ON DELETE RESTRICT,
        cantidad         INTEGER NOT NULL CHECK (cantidad > 0),
        precio_unitario  REAL NOT NULL DEFAULT 0 CHECK (precio_unitario >= 0),
        fecha_compra     TEXT NOT NULL CHECK (fecha_compra $_formatoFecha)
      )''');

    b.execute('''
      CREATE TABLE lote (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id      INTEGER NOT NULL REFERENCES producto(id) ON DELETE CASCADE,
        compra_id        INTEGER REFERENCES historial_compras(id) ON DELETE SET NULL,
        cantidad         INTEGER NOT NULL CHECK (cantidad >= 0),
        fecha_caducidad  TEXT CHECK (fecha_caducidad IS NULL OR fecha_caducidad $_formatoFecha),
        fecha_ingreso    TEXT NOT NULL CHECK (fecha_ingreso $_formatoFecha)
      )''');

    b.execute('''
      CREATE TABLE carrito (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id  INTEGER NOT NULL UNIQUE REFERENCES producto(id) ON DELETE CASCADE,
        cantidad     INTEGER NOT NULL DEFAULT 1 CHECK (cantidad > 0),
        agregado_en  TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
      )''');

    b.execute('''
      CREATE TABLE consumo (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id  INTEGER NOT NULL REFERENCES producto(id) ON DELETE CASCADE,
        lote_id      INTEGER REFERENCES lote(id) ON DELETE SET NULL,
        cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
        motivo       TEXT NOT NULL CHECK (motivo IN ('consumo', 'desecho')),
        fecha        TEXT NOT NULL CHECK (fecha $_formatoFecha)
      )''');

    // Índices para las consultas más frecuentes.
    b.execute('CREATE INDEX idx_lote_producto ON lote(producto_id, fecha_caducidad)');
    b.execute('CREATE INDEX idx_compra_producto ON historial_compras(producto_id)');
    b.execute('CREATE INDEX idx_compra_tienda ON historial_compras(tienda_id)');
    b.execute('CREATE INDEX idx_producto_categoria ON producto(categoria_id)');

    // Regla de negocio "Última compra": al insertar en Historial_Compras se
    // actualiza producto.ultima_tienda_id con la tienda de la compra.
    b.execute('''
      CREATE TRIGGER trg_compra_ultima_tienda
      AFTER INSERT ON historial_compras
      BEGIN
        UPDATE producto SET ultima_tienda_id = NEW.tienda_id WHERE id = NEW.producto_id;
      END''');

    // Si se borra una compra, la última tienda vuelve a ser la de la compra
    // más reciente que quede (o NULL).
    b.execute('''
      CREATE TRIGGER trg_compra_borrada
      AFTER DELETE ON historial_compras
      BEGIN
        UPDATE producto SET ultima_tienda_id = (
          SELECT h.tienda_id FROM historial_compras h
          WHERE h.producto_id = OLD.producto_id
          ORDER BY h.fecha_compra DESC, h.id DESC LIMIT 1
        ) WHERE id = OLD.producto_id;
      END''');

    await b.commit(noResult: true);
  }

  /// Datos de ejemplo para que la app se vea con información al presentarla.
  Future<void> _datosIniciales(Database db) async {
    final categorias = <String, String>{
      'Lácteos': '🥛',
      'Frutas y verduras': '🥕',
      'Carnes': '🥩',
      'Abarrotes': '🥫',
      'Panadería': '🍞',
      'Bebidas': '🧃',
      'Limpieza': '🧼',
      'Congelados': '🧊',
    };
    final idCat = <String, int>{};
    for (final e in categorias.entries) {
      idCat[e.key] = await db.insert('categoria', {'nombre': e.key, 'icono': e.value});
    }

    final idTienda = <String, int>{};
    for (final t in const [
      ['Mercado Hidalgo', 'Centro'],
      ['Soriana', 'Av. Tecnológico'],
      ['Bodega Aurrera', 'Blvd. López Mateos'],
      ['Tienda de la esquina', null],
    ]) {
      idTienda[t[0]!] = await db.insert('tienda', {'nombre': t[0], 'direccion': t[1]});
    }

    Future<int> producto(String nombre, String cat,
        {String unidad = 'pza', int minimo = 1, int aviso = 3, String? desc}) {
      return db.insert('producto', {
        'nombre': nombre,
        'descripcion': desc,
        'categoria_id': idCat[cat],
        'unidad': unidad,
        'stock_minimo': minimo,
        'dias_aviso': aviso,
      });
    }

    Future<void> compra(int prod, String tienda, int cant, double precio, int haceDias, int? caducaEn) async {
      final fecha = Fechas.masDias(-haceDias);
      final compraId = await db.insert('historial_compras', {
        'producto_id': prod,
        'tienda_id': idTienda[tienda],
        'cantidad': cant,
        'precio_unitario': precio,
        'fecha_compra': fecha,
      });
      await db.insert('lote', {
        'producto_id': prod,
        'compra_id': compraId,
        'cantidad': cant,
        'fecha_caducidad': caducaEn == null ? null : Fechas.masDias(caducaEn),
        'fecha_ingreso': fecha,
      });
    }

    final leche = await producto('Leche entera', 'Lácteos', unidad: 'L', minimo: 2, desc: 'Deslactosada 1 L');
    await compra(leche, 'Soriana', 2, 28.5, 6, 2);
    await compra(leche, 'Bodega Aurrera', 3, 26.9, 1, 12);

    final yogurt = await producto('Yogurt natural', 'Lácteos', minimo: 1);
    await compra(yogurt, 'Soriana', 1, 19.0, 10, -1);

    final huevo = await producto('Huevo', 'Abarrotes', minimo: 12, aviso: 5, desc: 'Blanco');
    await compra(huevo, 'Mercado Hidalgo', 6, 3.2, 4, 14);

    final pan = await producto('Pan de caja', 'Panadería', unidad: 'paquete', minimo: 1, aviso: 2);
    await compra(pan, 'Tienda de la esquina', 1, 52.0, 5, 0);

    final arroz = await producto('Arroz', 'Abarrotes', unidad: 'kg', minimo: 1, aviso: 15);
    await compra(arroz, 'Bodega Aurrera', 2, 32.0, 20, 180);
    await compra(arroz, 'Soriana', 1, 35.5, 2, 240);

    final atun = await producto('Atún en agua', 'Abarrotes', unidad: 'lata', minimo: 2, aviso: 30);
    await db.insert('historial_compras', {
      'producto_id': atun,
      'tienda_id': idTienda['Bodega Aurrera'],
      'cantidad': 4,
      'precio_unitario': 18.5,
      'fecha_compra': Fechas.masDias(-30),
    });

    final manzana = await producto('Manzana roja', 'Frutas y verduras', unidad: 'kg', minimo: 1, aviso: 3);
    await compra(manzana, 'Mercado Hidalgo', 2, 45.0, 3, 3);

    final pollo = await producto('Pechuga de pollo', 'Carnes', unidad: 'kg', minimo: 1, aviso: 1);
    await compra(pollo, 'Mercado Hidalgo', 1, 120.0, 1, 1);

    final jabon = await producto('Detergente', 'Limpieza', unidad: 'bolsa', minimo: 1);
    await compra(jabon, 'Soriana', 1, 89.0, 15, null);

    final jugo = await producto('Jugo de naranja', 'Bebidas', unidad: 'botella', minimo: 1, aviso: 4);
    await compra(jugo, 'Bodega Aurrera', 3, 24.0, 2, 7);
  }
}
