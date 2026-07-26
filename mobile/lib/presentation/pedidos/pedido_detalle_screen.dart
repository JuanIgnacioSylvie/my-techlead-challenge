import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/estados.dart';
import '../../data/repositories.dart';
import 'pedido_detalle_bloc.dart';

/// Detalle de un pedido: renglones + acciones para avanzar o cancelar el estado.
class PedidoDetalleScreen extends StatelessWidget {
  final int pedidoId;

  const PedidoDetalleScreen({super.key, required this.pedidoId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PedidoDetalleBloc(
        pedidosRepository: context.read<PedidosRepository>(),
        pedidoId: pedidoId,
      )..add(const PedidoDetalleSolicitado()),
      child: const _DetalleView(),
    );
  }
}

class _DetalleView extends StatelessWidget {
  const _DetalleView();

  Future<void> _confirmarYCambiar(
    BuildContext context, {
    required String nuevoEstado,
    required String titulo,
    required String mensaje,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<PedidoDetalleBloc>().add(PedidoEstadoCambiado(nuevoEstado));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: BlocConsumer<PedidoDetalleBloc, PedidoDetalleState>(
        listenWhen: (prev, curr) =>
            curr.cambioExitoso ||
            (curr.error != null && curr.status == DetalleStatus.listo),
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.cambioExitoso) {
            final etiqueta = EstadoPedidoUi.de(state.pedido!.estado).etiqueta;
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('Estado actualizado a $etiqueta'),
                backgroundColor: Colors.green.shade700,
              ));
          } else if (state.error != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ));
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            DetalleStatus.cargando =>
              const Center(child: CircularProgressIndicator()),
            DetalleStatus.error => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error ?? 'No se pudo cargar el pedido.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context
                            .read<PedidoDetalleBloc>()
                            .add(const PedidoDetalleSolicitado()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            DetalleStatus.listo ||
            DetalleStatus.actualizando =>
              _Contenido(state: state, onCambiar: _confirmarYCambiar),
          };
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  final PedidoDetalleState state;
  final Future<void> Function(
    BuildContext context, {
    required String nuevoEstado,
    required String titulo,
    required String mensaje,
  }) onCambiar;

  const _Contenido({required this.state, required this.onCambiar});

  String _fecha(DateTime f) {
    final local = f.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final pedido = state.pedido!;
    final ui = EstadoPedidoUi.de(pedido.estado);
    final siguiente = EstadoPedidoUi.siguiente(pedido.estado);
    final puedeCancelar = EstadoPedidoUi.puedeCancelar(pedido.estado);
    final ocupado = state.status == DetalleStatus.actualizando;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (ocupado) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    'Pedido #${pedido.pedidoId}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  _EstadoChip(estado: pedido.estado),
                ],
              ),
              const SizedBox(height: 16),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.storefront_outlined,
                    label: 'Cliente',
                    value: pedido.clienteNombre,
                  ),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Registrado por',
                    value: pedido.usuarioNombre,
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Creado',
                    value: _fecha(pedido.fechaCreacion),
                  ),
                  _InfoRow(
                    icon: Icons.update_outlined,
                    label: 'Actualizado',
                    value: _fecha(pedido.fechaActualizacion),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Productos',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...pedido.renglones.map(
                (r) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: ListTile(
                    title: Text(r.nombre),
                    subtitle: Text(
                        '${r.sku} · ${r.cantidad} × \$${r.precioUnitario.toStringAsFixed(2)}'),
                    trailing: Text(
                      '\$${r.subtotal.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: \$${pedido.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
              ),
              if (siguiente == null && !puedeCancelar) ...[
                const SizedBox(height: 24),
                Card(
                  color: ui.color.withAlpha(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(ui.icono, color: ui.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este pedido está en estado final (${ui.etiqueta}). '
                            'No admite más cambios.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        if (siguiente != null || puedeCancelar)
          Material(
            elevation: 8,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (siguiente != null) ...[
                      FilledButton.icon(
                        onPressed: ocupado
                            ? null
                            : () {
                                final nextUi = EstadoPedidoUi.de(siguiente);
                                onCambiar(
                                  context,
                                  nuevoEstado: siguiente,
                                  titulo: 'Avanzar pedido',
                                  mensaje:
                                      '¿Pasar el pedido #${pedido.pedidoId} '
                                      'a "${nextUi.etiqueta}"?',
                                );
                              },
                        icon: Icon(EstadoPedidoUi.de(siguiente).icono),
                        label: Text(
                            'Marcar como ${EstadoPedidoUi.de(siguiente).etiqueta}'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      if (puedeCancelar) const SizedBox(height: 8),
                    ],
                    if (puedeCancelar)
                      OutlinedButton.icon(
                        onPressed: ocupado
                            ? null
                            : () => onCambiar(
                                  context,
                                  nuevoEstado: 'Cancelado',
                                  titulo: 'Cancelar pedido',
                                  mensaje:
                                      '¿Cancelar el pedido #${pedido.pedidoId}? '
                                      'Se repondrá el stock descontado.',
                                ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar pedido'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final ui = EstadoPedidoUi.de(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ui.color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ui.icono, size: 16, color: ui.color),
          const SizedBox(width: 6),
          Text(
            ui.etiqueta,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: ui.color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: cs.primary),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant)),
      subtitle: Text(value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}
