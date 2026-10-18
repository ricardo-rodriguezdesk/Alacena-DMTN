import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/estatus.dart';
import '../models/evento_calendario.dart';
import '../state/alacena_provider.dart';
import '../utils/estatus_ui.dart';
import '../utils/fechas.dart';
import '../widgets/comunes.dart';
import 'dia_modal.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _foco = DateTime.now();
  DateTime? _seleccionado;
  CalendarFormat _formato = CalendarFormat.month;

  void _abrirDia(DateTime dia) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Productos del día',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, a1, a2) => DiaModal(dia: dia),
      transitionBuilder: (ctx, anim, a2, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AlacenaProvider>();
    final scheme = Theme.of(context).colorScheme;
    List<EventoCalendario> cargarEventos(DateTime d) => prov.eventosDe(Fechas.clave(d));

    // Próximos 14 días con eventos.
    final proximos = <(DateTime, List<EventoCalendario>)>[];
    final hoy = Fechas.hoy();
    for (var i = 0; i < 14; i++) {
      final d = DateTime(hoy.year, hoy.month, hoy.day + i);
      final ev = cargarEventos(d);
      if (ev.isNotEmpty) proximos.add((d, ev));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(
            title: Text('Calendario'),
            actions: [CarritoBadgeButton(), SizedBox(width: 8)],
          ),
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TableCalendar<EventoCalendario>(
                  locale: 'es_MX',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _foco,
                  calendarFormat: _formato,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Mes',
                    CalendarFormat.twoWeeks: '2 semanas',
                    CalendarFormat.week: 'Semana',
                  },
                  eventLoader: cargarEventos,
                  selectedDayPredicate: (d) => isSameDay(_seleccionado, d),
                  onDaySelected: (sel, foco) {
                    setState(() {
                      _seleccionado = sel;
                      _foco = foco;
                    });
                    _abrirDia(sel);
                  },
                  onFormatChanged: (f) => setState(() => _formato = f),
                  onPageChanged: (f) => _foco = f,
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    titleTextFormatter: (d, locale) {
                      final s = DateFormat.yMMMM('es_MX').format(d);
                      return s[0].toUpperCase() + s.substring(1);
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.30),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold),
                    selectedDecoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders<EventoCalendario>(
                    // Un punto por cada producto con alerta ese día, con el color de su estatus.
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final visibles = events.take(5).toList();
                      return Positioned(
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final e in visibles)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(color: e.principal.color, shape: BoxShape.circle),
                              ),
                            if (events.length > 5)
                              Text('+', style: TextStyle(fontSize: 9, color: scheme.onSurface)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final e in Estatus.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(e == Estatus.ok ? 'Caduca (sin alerta)' : e.etiqueta,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: EncabezadoSeccion('Próximos 14 días')),
          if (proximos.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sin eventos en los próximos días.', textAlign: TextAlign.center),
              ),
            )
          else
            SliverList.builder(
              itemCount: proximos.length,
              itemBuilder: (context, i) {
                final (dia, ev) = proximos[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ev.first.principal.color.withValues(alpha: 0.15),
                    child: Text('${dia.day}',
                        style: TextStyle(color: ev.first.principal.color, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(Fechas.relativa(Fechas.clave(dia))),
                  subtitle: Text(ev.map((e) => e.producto.nombre).join(', '),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${ev.length}'),
                  onTap: () => _abrirDia(dia),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
