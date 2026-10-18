import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../services/notificaciones_service.dart';
import '../state/alacena_provider.dart';
import 'alertas_screen.dart';
import 'caducan_hoy_screen.dart';
import 'calendario_screen.dart';
import 'inventario_screen.dart';
import 'mas_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    final notif = NotificacionesService.instance;
    notif.onAbrirFecha = _abrirFecha;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notif.pedirPermiso();
      final p = notif.tomarPayloadInicial();
      if (p != null) _abrirFecha(p);
    });
  }

  void _abrirFecha(String fecha) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => CaducanHoyScreen(fecha: fecha)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertas = context.select<AlacenaProvider, int>((p) => p.alertas.length);
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: const [
          AlertasScreen(),
          CalendarioScreen(),
          InventarioScreen(),
          MasScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: alertas > 0,
              label: Text('$alertas'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alertas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          const NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Alacena',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
