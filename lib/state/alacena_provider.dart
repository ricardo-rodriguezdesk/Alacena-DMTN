import 'package:flutter/foundation.dart';

import '../models/carrito_item.dart';
import '../models/categoria.dart';
import '../models/compra.dart';
import '../models/estatus.dart';
import '../models/evento_calendario.dart';
import '../models/lote.dart';
import '../models/producto.dart';
import '../models/tienda.dart';
import '../repositories/carrito_repository.dart';
import '../repositories/catalogo_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../services/imagen_service.dart';
import '../services/notificaciones_service.dart';
import '../utils/fechas.dart';

/// Existencia inicial opcional al dar de alta un producto.
class ExistenciaInicial {
  final int cantidad;
  final String? fechaCaducidad;
  final int? tiendaId;
  final double precio;
  const ExistenciaInicial({required this.cantidad, this.fechaCaducidad, this.tiendaId, this.precio = 0});
}

/// Estado global de la app. Las pantallas leen de aquí y, después de cada
/// cambio en la base de datos, se llama a [cargar] para refrescar todo.
class AlacenaProvider extends ChangeNotifier {
  final _productos = ProductoRepository();
  final _catalogo = CatalogoRepository();
  final _inventario = InventarioRepository();
  final _carrito = CarritoRepository();

  bool cargando = true;
  String? error;
  List<Producto> productos = [];
  List<Categoria> categorias = [];
  List<Tienda> tiendas = [];
  List<LoteCaducidad> lotes = [];
  List<CarritoItem> carrito = [];
  Map<String, List<EventoCalendario>> eventos = {};

  int get carritoCount => carrito.length;

  Producto? productoPorId(int id) {
    for (final p in productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Artículos con alguna alerta, del más grave al menos grave.
  List<Producto> get alertas {
    final l = productos.where((p) => p.estatusPrincipal != Estatus.ok).toList();
    l.sort((a, b) {
      final c = a.estatusPrincipal.index.compareTo(b.estatusPrincipal.index);
      if (c != 0) return c;
      return (a.proximaCaducidad ?? '9999-99-99').compareTo(b.proximaCaducidad ?? '9999-99-99');
    });
    return l;
  }

  Future<void> cargar() async {
    try {
      productos = await _productos.todos();
      categorias = await _catalogo.categorias();
      tiendas = await _catalogo.tiendas();
      lotes = await _inventario.lotesConCaducidad();
      carrito = await _carrito.items();
      eventos = _calcularEventos();
      error = null;
    } catch (e) {
      error = '$e';
      debugPrint('Error al cargar datos: $e');
    }
    cargando = false;
    notifyListeners();
    _programarAlarmas();
  }

  // ---------------- Calendario ----------------

  Estatus _tipoLote(LoteCaducidad l, Producto p) {
    final d = Fechas.diasHasta(l.fechaCaducidad);
    if (d < 0) return Estatus.caducado;
    if (d <= p.diasAviso) return Estatus.porCaducar;
    return Estatus.ok;
  }

  Map<String, List<EventoCalendario>> _calcularEventos() {
    final porId = {for (final p in productos) p.id!: p};
    final mapa = <String, Map<int, EventoCalendario>>{};

    void agregar(String dia, Producto p, Estatus tipo, int unidades) {
      final delDia = mapa.putIfAbsent(dia, () => <int, EventoCalendario>{});
      final ev = delDia.putIfAbsent(p.id!, () => EventoCalendario(producto: p, tipos: <Estatus>{}));
      ev.tipos.add(tipo);
      ev.unidadesQueCaducan += unidades;
    }

    // Cada lote aparece el día que caduca.
    for (final l in lotes) {
      final p = porId[l.productoId];
      if (p == null) continue;
      agregar(l.fechaCaducidad, p, _tipoLote(l, p), l.cantidad);
    }
    // Las alertas de existencia (agotado / por agotarse) se muestran hoy.
    final hoy = Fechas.hoyClave();
    for (final p in productos) {
      if (p.stock <= 0) {
        agregar(hoy, p, Estatus.agotado, 0);
      } else if (p.stock <= p.stockMinimo) {
        agregar(hoy, p, Estatus.porAgotarse, 0);
      }
    }
    return mapa.map((k, v) {
      final lista = v.values.toList()..sort((a, b) => a.principal.index.compareTo(b.principal.index));
      return MapEntry(k, lista);
    });
  }

  List<EventoCalendario> eventosDe(String dia) => eventos[dia] ?? const [];

  /// Lotes que caducan exactamente en [dia].
  List<(Producto, LoteCaducidad)> lotesQueCaducan(String dia) {
    final res = <(Producto, LoteCaducidad)>[];
    for (final l in lotes) {
      if (l.fechaCaducidad != dia) continue;
      final p = productoPorId(l.productoId);
      if (p != null) res.add((p, l));
    }
    return res;
  }

  void _programarAlarmas() {
    final hoy = Fechas.hoyClave();
    final alarmas = <AlarmaLote>[];
    for (final l in lotes) {
      if (l.fechaCaducidad.compareTo(hoy) < 0) continue;
      final p = productoPorId(l.productoId);
      if (p == null || !p.notificar) continue;
      alarmas.add(AlarmaLote(
        loteId: l.loteId,
        producto: p.nombre,
        cantidad: l.cantidad,
        unidad: p.unidad,
        fecha: l.fechaCaducidad,
        hora: p.horaAlarma,
      ));
    }
    NotificacionesService.instance.reprogramar(alarmas);
  }

  // ---------------- Productos ----------------

  Future<void> guardarProducto(Producto p, {ExistenciaInicial? inicial, String? imagenAnterior}) async {
    if (p.id == null) {
      final id = await _productos.insertar(p);
      if (inicial != null && inicial.cantidad > 0) {
        if (inicial.tiendaId != null) {
          await _inventario.registrarCompra(
            Compra(
              productoId: id,
              tiendaId: inicial.tiendaId!,
              cantidad: inicial.cantidad,
              precioUnitario: inicial.precio,
              fechaCompra: Fechas.hoyClave(),
            ),
            fechaCaducidad: inicial.fechaCaducidad,
          );
        } else {
          await _inventario.guardarLote(Lote(
            productoId: id,
            cantidad: inicial.cantidad,
            fechaCaducidad: inicial.fechaCaducidad,
            fechaIngreso: Fechas.hoyClave(),
          ));
        }
      }
    } else {
      await _productos.actualizar(p);
    }
    if (imagenAnterior != null && imagenAnterior != p.imagen) {
      await ImagenService.eliminar(imagenAnterior);
    }
    await cargar();
  }

  Future<void> eliminarProducto(Producto p) async {
    await _productos.eliminar(p.id!);
    await ImagenService.eliminar(p.imagen);
    await cargar();
  }

  // ---------------- Inventario ----------------

  Future<void> consumir(int productoId, int cantidad, {String motivo = 'consumo'}) async {
    await _inventario.consumir(productoId, cantidad, motivo: motivo);
    await cargar();
  }

  Future<void> guardarLote(Lote l) async {
    await _inventario.guardarLote(l);
    await cargar();
  }

  Future<void> eliminarLote(int id) async {
    await _inventario.eliminarLote(id);
    await cargar();
  }

  Future<void> desecharLote(int id) async {
    await _inventario.desecharLote(id);
    await cargar();
  }

  Future<int> desecharCaducados(int productoId) async {
    final n = await _inventario.desecharCaducados(productoId);
    await cargar();
    return n;
  }

  Future<void> registrarCompra(Compra c, {String? fechaCaducidad, int? carritoItemId}) async {
    await _inventario.registrarCompra(c, fechaCaducidad: fechaCaducidad);
    if (carritoItemId != null) await _carrito.eliminar(carritoItemId);
    await cargar();
  }

  Future<void> eliminarCompra(int compraId) async {
    await _inventario.eliminarCompra(compraId);
    await cargar();
  }

  // ---------------- Carrito ----------------

  Future<bool> agregarAlCarrito(int productoId, {int cantidad = 1}) async {
    final nuevo = await _carrito.agregar(productoId, cantidad: cantidad);
    await cargar();
    return nuevo;
  }

  Future<void> cambiarCantidadCarrito(int itemId, int cantidad) async {
    await _carrito.cambiarCantidad(itemId, cantidad);
    await cargar();
  }

  /// Se quita primero de la lista en memoria para que el Dismissible
  /// desaparezca de inmediato y después se borra en la base de datos.
  Future<void> quitarDelCarrito(int itemId) async {
    carrito = carrito.where((i) => i.id != itemId).toList();
    notifyListeners();
    await _carrito.eliminar(itemId);
    await cargar();
  }

  Future<void> vaciarCarrito() async {
    await _carrito.vaciar();
    await cargar();
  }

  // ---------------- Catálogos ----------------

  Future<void> guardarCategoria(Categoria c) async {
    await _catalogo.guardarCategoria(c);
    await cargar();
  }

  Future<void> eliminarCategoria(int id) async {
    await _catalogo.eliminarCategoria(id);
    await cargar();
  }

  Future<int> guardarTienda(Tienda t) async {
    final id = await _catalogo.guardarTienda(t);
    await cargar();
    return id;
  }

  Future<void> eliminarTienda(int id) async {
    await _catalogo.eliminarTienda(id);
    await cargar();
  }
}
