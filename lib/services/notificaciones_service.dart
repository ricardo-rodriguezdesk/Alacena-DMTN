import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Alarma de un lote que caduca en [fecha] ('yyyy-MM-dd') a la [hora] ('HH:mm')
/// configurada en el producto.
class AlarmaLote {
  final int loteId;
  final String producto;
  final int cantidad;
  final String unidad;
  final String fecha;
  final String hora;

  const AlarmaLote({
    required this.loteId,
    required this.producto,
    required this.cantidad,
    required this.unidad,
    required this.fecha,
    required this.hora,
  });
}

/// Alarmas locales. Al tocar la notificación se abre la pantalla
/// "Caducan hoy" con los productos que caducan ese día (payload = fecha).
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instance = NotificacionesService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;
  String? _payloadInicial;

  /// Se asigna desde la UI para navegar cuando se toca una notificación.
  void Function(String fecha)? onAbrirFecha;

  static const _canal = AndroidNotificationDetails(
    'caducidad',
    'Caducidad de productos',
    channelDescription: 'Avisos de productos de la alacena que caducan',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _detalles = NotificationDetails(android: _canal, iOS: DarwinNotificationDetails());

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const ajustes = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        ajustes,
        onDidReceiveNotificationResponse: (respuesta) {
          final p = respuesta.payload;
          if (p != null && p.isNotEmpty) onAbrirFecha?.call(p);
        },
      );
      final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
      if (lanzamiento?.didNotificationLaunchApp ?? false) {
        _payloadInicial = lanzamiento!.notificationResponse?.payload;
      }
      _listo = true;
    } catch (e) {
      debugPrint('No se pudieron inicializar las notificaciones: $e');
    }
  }

  /// Pide permiso de notificaciones (Android 13+). Se llama ya con la UI visible.
  Future<void> pedirPermiso() async {
    if (!_listo) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Permiso de notificaciones: $e');
    }
  }

  /// Payload con el que se abrió la app (solo se entrega una vez).
  String? tomarPayloadInicial() {
    final p = _payloadInicial;
    _payloadInicial = null;
    return p;
  }

  /// Cancela y vuelve a programar todas las alarmas.
  Future<void> reprogramar(List<AlarmaLote> alarmas) async {
    if (!_listo) return;
    try {
      await _plugin.cancelAll();
      final ahora = DateTime.now();
      var programadas = 0;
      for (final a in alarmas) {
        if (programadas >= 60) break; // iOS limita a 64 pendientes
        final f = a.fecha.split('-').map(int.parse).toList();
        final h = a.hora.split(':').map(int.parse).toList();
        final cuando = DateTime(f[0], f[1], f[2], h[0], h[1]);
        if (!cuando.isAfter(ahora)) continue;
        await _plugin.zonedSchedule(
          a.loteId,
          '⚠️ Hoy caduca: ${a.producto}',
          '${a.cantidad} ${a.unidad} caducan hoy. Toca para ver los productos del día.',
          tz.TZDateTime.from(cuando, tz.UTC),
          _detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: a.fecha,
        );
        programadas++;
      }
    } catch (e) {
      debugPrint('Error al programar alarmas: $e');
    }
  }

  /// Notificación inmediata para probar las alarmas durante la presentación.
  Future<void> probar(String fecha, int cantidadProductos) async {
    if (!_listo) return;
    await _plugin.show(
      999999,
      '⚠️ Productos que caducan hoy',
      cantidadProductos == 0
          ? 'No hay productos que caduquen hoy 🎉'
          : '$cantidadProductos producto(s) caducan hoy. Toca para verlos.',
      _detalles,
      payload: fecha,
    );
  }
}
