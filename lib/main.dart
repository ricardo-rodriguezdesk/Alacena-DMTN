import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/notificaciones_service.dart';
import 'state/alacena_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  Intl.defaultLocale = 'es_MX';
  await NotificacionesService.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AlacenaProvider()..cargar(),
      child: const AlacenaApp(),
    ),
  );
}
