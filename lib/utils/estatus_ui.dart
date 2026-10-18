import 'package:flutter/material.dart';

import '../models/estatus.dart';

/// Identificación rápida del estatus: color + icono + etiqueta.
extension EstatusUI on Estatus {
  String get etiqueta => switch (this) {
        Estatus.caducado => 'Caducado',
        Estatus.agotado => 'Sin existencia',
        Estatus.porCaducar => 'Por caducar',
        Estatus.porAgotarse => 'Por agotarse',
        Estatus.ok => 'En orden',
      };

  IconData get icono => switch (this) {
        Estatus.caducado => Icons.dangerous_rounded,
        Estatus.agotado => Icons.remove_shopping_cart_rounded,
        Estatus.porCaducar => Icons.hourglass_bottom_rounded,
        Estatus.porAgotarse => Icons.trending_down_rounded,
        Estatus.ok => Icons.check_circle_rounded,
      };

  Color get color => switch (this) {
        Estatus.caducado => const Color(0xFFD32F2F),
        Estatus.agotado => const Color(0xFF546E7A),
        Estatus.porCaducar => const Color(0xFFEF6C00),
        Estatus.porAgotarse => const Color(0xFF8E24AA),
        Estatus.ok => const Color(0xFF2E7D32),
      };
}
