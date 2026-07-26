import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/estados.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import 'pedido_detalle_screen.dart';
import 'pedidos_bloc.dart';

/// Pantalla 5: pedidos existentes, con filtro por estado.
/// Desde acá el operador entra al detalle y avanza/cancela el pedido.
class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PedidosBloc(
        pedidosRepository: context.read<PedidosRepository>(),
      )..add(const PedidosSolicitados()),
      child: const _PedidosView(),
    );
  }
}

class _PedidosView extends StatelessWidget {
  const _PedidosView();

  String? _filtroActual(PedidosState state) => switch (state) {
        PedidosLoading(:final estadoFiltro) => estadoFiltro,
        PedidosLoaded(:final estadoFiltro) => estadoFiltro,
        PedidosError(:final estadoFiltro) => estadoFiltro,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: BlocBuilder<PedidosBloc, PedidosState>(
        builder: (context, state) {
          final filtro = _filtroActual(state);

          return Column(
            children: [
              _FiltroEstados(
                seleccionado: filtro,
                habilitado: state is! PedidosLoading,
                onCambio: (estado) => context
                    .read<PedidosBloc>()
                    .add(PedidosSolicitados(estadoFiltro: estado)),
              ),
              Expanded(
                child: switch (state) {
                  PedidosLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  PedidosError(:final mensaje) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(mensaje, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => context.read<PedidosBloc>().add(
                                  PedidosSolicitados(estadoFiltro: filtro)),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  PedidosLoaded(:final pedidos) => pedidos.isEmpty
                      ? const Center(
                          child: Text('No hay pedidos con ese estado.'))
                      : RefreshIndicator(
                          onRefresh: () async => context
                              .read<PedidosBloc>()
                              .add(PedidosSolicitados(estadoFiltro: filtro)),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: pedidos.length,
                            itemBuilder: (context, i) => _PedidoTile(
                              pedido: pedidos[i],
                              onVolver: () => context.read<PedidosBloc>().add(
                                  PedidosSolicitados(estadoFiltro: filtro)),
                            ),
                          ),
                        ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FiltroEstados extends StatelessWidget {
  final String? seleccionado;
  final bool habilitado;
  final ValueChanged<String?> onCambio;

  const _FiltroEstados({
    required this.seleccionado,
    required this.habilitado,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Todos'),
              selected: seleccionado == null,
              onSelected: habilitado ? (_) => onCambio(null) : null,
            ),
          ),
          ...EstadoPedidoUi.valores.map((estado) {
            final ui = EstadoPedidoUi.de(estado);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(ui.icono, size: 16, color: ui.color),
                label: Text(ui.etiqueta),
                selected: seleccionado == estado,
                onSelected: habilitado ? (_) => onCambio(estado) : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  final PedidoResumen pedido;
  final VoidCallback onVolver;

  const _PedidoTile({required this.pedido, required this.onVolver});

  String _fecha(DateTime f) {
    final local = f.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)} ${dos(local.hour)}:${dos(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ui = EstadoPedidoUi.de(pedido.estado);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PedidoDetalleScreen(pedidoId: pedido.pedidoId),
            ),
          );
          onVolver(); // el estado pudo cambiar en el detalle
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${pedido.pedidoId}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pedido.clienteNombre,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _fecha(pedido.fechaCreacion),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: ui.color.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ui.color.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ui.icono, size: 14, color: ui.color),
                        const SizedBox(width: 4),
                        Text(
                          ui.etiqueta,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: ui.color),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${pedido.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
