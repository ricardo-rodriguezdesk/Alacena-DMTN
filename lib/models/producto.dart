import '../utils/fechas.dart';
import 'estatus.dart';

const unidadesValidas = ['pza', 'paquete', 'lata', 'botella', 'caja', 'bolsa', 'kg', 'g', 'L', 'ml'];

class Producto {
  final int? id;
  final String nombre;
  final String? descripcion;
  final int categoriaId;
  final String? imagen;
  final String unidad;
  final int stockMinimo;
  final int diasAviso;

  /// Campo para las alarmas locales: si está activo, el día que caduca un
  /// lote se lanza una notificación a la hora indicada en [horaAlarma].
  final bool notificar;
  final String horaAlarma;
  final int? ultimaTiendaId;

  // Campos calculados (solo lectura, vienen de la consulta con JOIN).
  final String? categoriaNombre;
  final String categoriaIcono;
  final String? ultimaTiendaNombre;
  final int stock;
  final String? proximaCaducidad;
  final bool enCarrito;

  const Producto({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.categoriaId,
    this.imagen,
    this.unidad = 'pza',
    this.stockMinimo = 1,
    this.diasAviso = 3,
    this.notificar = true,
    this.horaAlarma = '09:00',
    this.ultimaTiendaId,
    this.categoriaNombre,
    this.categoriaIcono = '📦',
    this.ultimaTiendaNombre,
    this.stock = 0,
    this.proximaCaducidad,
    this.enCarrito = false,
  });

  factory Producto.fromMap(Map<String, Object?> m) => Producto(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String?,
        categoriaId: m['categoria_id'] as int,
        imagen: m['imagen'] as String?,
        unidad: (m['unidad'] as String?) ?? 'pza',
        stockMinimo: (m['stock_minimo'] as num?)?.toInt() ?? 1,
        diasAviso: (m['dias_aviso'] as num?)?.toInt() ?? 3,
        notificar: ((m['notificar'] as num?)?.toInt() ?? 1) == 1,
        horaAlarma: (m['hora_alarma'] as String?) ?? '09:00',
        ultimaTiendaId: m['ultima_tienda_id'] as int?,
        categoriaNombre: m['categoria_nombre'] as String?,
        categoriaIcono: (m['categoria_icono'] as String?) ?? '📦',
        ultimaTiendaNombre: m['ultima_tienda_nombre'] as String?,
        stock: (m['stock'] as num?)?.toInt() ?? 0,
        proximaCaducidad: m['proxima_caducidad'] as String?,
        enCarrito: ((m['en_carrito'] as num?)?.toInt() ?? 0) > 0,
      );

  /// Solo columnas de la tabla. `ultima_tienda_id` no se incluye: la
  /// mantiene el trigger de Historial_Compras.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre.trim(),
        'descripcion': (descripcion == null || descripcion!.trim().isEmpty) ? null : descripcion!.trim(),
        'categoria_id': categoriaId,
        'imagen': imagen,
        'unidad': unidad,
        'stock_minimo': stockMinimo,
        'dias_aviso': diasAviso,
        'notificar': notificar ? 1 : 0,
        'hora_alarma': horaAlarma,
      };

  /// Todos los estatus que aplican, ordenados por severidad.
  List<Estatus> get estatus {
    final res = <Estatus>[];
    if (proximaCaducidad != null) {
      final d = Fechas.diasHasta(proximaCaducidad!);
      if (d < 0) {
        res.add(Estatus.caducado);
      } else if (d <= diasAviso) {
        res.add(Estatus.porCaducar);
      }
    }
    if (stock <= 0) {
      res.add(Estatus.agotado);
    } else if (stock <= stockMinimo) {
      res.add(Estatus.porAgotarse);
    }
    if (res.isEmpty) res.add(Estatus.ok);
    res.sort((a, b) => a.index.compareTo(b.index));
    return res;
  }

  Estatus get estatusPrincipal => estatus.first;
}
