import 'package:intl/intl.dart';

/// Utilidades de fechas. En la base de datos las fechas se guardan como
/// texto 'yyyy-MM-dd' para que se puedan comparar y ordenar como cadenas.
class Fechas {
  Fechas._();

  static DateTime hoy() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// Convierte cualquier DateTime (local o UTC) a 'yyyy-MM-dd'.
  static String clave(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_dos(d.month)}-${_dos(d.day)}';

  static String hoyClave() => clave(hoy());

  /// Fecha a [dias] días de hoy en formato 'yyyy-MM-dd'.
  static String masDias(int dias) {
    final h = hoy();
    return clave(DateTime(h.year, h.month, h.day + dias));
  }

  static DateTime parse(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// Días que faltan para [s] (negativo si ya pasó).
  static int diasHasta(String s) {
    final diff = parse(s).difference(hoy());
    return (diff.inHours / 24).round();
  }

  static String corta(String s) => DateFormat('d MMM yyyy', 'es_MX').format(parse(s));

  static String larga(DateTime d) {
    final t = DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es_MX').format(d);
    return t[0].toUpperCase() + t.substring(1);
  }

  static String relativa(String s) {
    final d = diasHasta(s);
    if (d == 0) return 'Hoy';
    if (d == 1) return 'Mañana';
    if (d == -1) return 'Ayer';
    if (d > 0) return 'En $d días';
    return 'Hace ${-d} días';
  }

  static String moneda(num v) => NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(v);
}
