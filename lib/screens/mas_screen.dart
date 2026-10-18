import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notificaciones_service.dart';
import '../state/alacena_provider.dart';
import '../utils/fechas.dart';
import 'caducan_hoy_screen.dart';
import 'categorias_screen.dart';
import 'estadisticas_screen.dart';
import 'tiendas_screen.dart';

class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void ir(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final prov = context.watch<AlacenaProvider>();

    final opciones = <(IconData, String, String, VoidCallback)>[
      (Icons.category_outlined, 'Categorías', '${prov.categorias.length} categorías', () => ir(const CategoriasScreen())),
      (Icons.storefront_outlined, 'Tiendas', '${prov.tiendas.length} tiendas', () => ir(const TiendasScreen())),
      (Icons.insights_outlined, 'Estadísticas', 'Gasto por tienda y desperdicio', () => ir(const EstadisticasScreen())),
      (Icons.event_busy_outlined, 'Caducan hoy', 'Productos que vencen hoy', () => ir(const CaducanHoyScreen())),
      (
        Icons.notifications_active_outlined,
        'Probar alarma',
        'Lanza ahora la notificación del día',
        () {
          final hoy = Fechas.hoyClave();
          NotificacionesService.instance.probar(hoy, prov.lotesQueCaducan(hoy).length);
        },
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Más')),
          SliverList.builder(
            itemCount: opciones.length,
            itemBuilder: (context, i) {
              final (icono, titulo, sub, accion) = opciones[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Icon(icono),
                  title: Text(titulo),
                  subtitle: Text(sub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: accion,
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'Alacena',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Text('🫙', style: TextStyle(fontSize: 40)),
                  children: const [
                    Text('Práctica 2 · Base de datos local.\n'
                        'Inventario doméstico con control de caducidad (FEFO), '
                        'alertas, calendario, lista de compras y trazabilidad por tienda.'),
                  ],
                ),
                icon: const Icon(Icons.info_outline),
                label: const Text('Acerca de'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
