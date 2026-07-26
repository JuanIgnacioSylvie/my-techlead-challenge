import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../confirmacion/confirmacion_screen.dart';
import 'pedido_bloc.dart';

/// Pantalla 3: formulario de pedido (cliente + productos + cantidades).
class PedidoScreen extends StatelessWidget {
  final List<Producto> productos;

  const PedidoScreen({super.key, required this.productos});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PedidoBloc(
        catalogoRepository: context.read<CatalogoRepository>(),
        pedidosRepository: context.read<PedidosRepository>(),
        productos: productos.where((p) => p.stock > 0).toList(),
      )..add(const PedidoIniciado()),
      child: const _PedidoView(),
    );
  }
}

class _PedidoView extends StatelessWidget {
  const _PedidoView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo pedido')),
      body: BlocConsumer<PedidoBloc, PedidoState>(
        listener: (context, state) {
          if (state.status == PedidoStatus.exito) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ConfirmacionScreen(resultado: state.resultado!),
              ),
            );
          } else if (state.error != null &&
              state.status == PedidoStatus.listo) {
            // Falla del envío (p.ej. 409 stock insuficiente): se informa
            // y el carrito queda intacto para corregir y reintentar.
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConfirmacionScreen.error(mensaje: state.error!),
              ),
            );
          }
        },
        listenWhen: (prev, curr) =>
            prev.status != curr.status || prev.error != curr.error,
        builder: (context, state) {
          return switch (state.status) {
            PedidoStatus.cargandoClientes =>
              const Center(child: CircularProgressIndicator()),
            PedidoStatus.errorCarga => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error ?? 'No se pudieron cargar los clientes.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context
                            .read<PedidoBloc>()
                            .add(const PedidoIniciado()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            _ => _Formulario(state: state),
          };
        },
      ),
    );
  }
}

class _Formulario extends StatelessWidget {
  final PedidoState state;

  const _Formulario({required this.state});

  @override
  Widget build(BuildContext context) {
    final enviando = state.status == PedidoStatus.enviando;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<Cliente>(
                initialValue: state.clienteSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  border: OutlineInputBorder(),
                ),
                items: state.clientes
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child:
                              Text(c.nombre, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: enviando
                    ? null
                    : (c) {
                        if (c != null) {
                          context
                              .read<PedidoBloc>()
                              .add(PedidoClienteSeleccionado(c));
                        }
                      },
              ),
              const SizedBox(height: 16),
              Text('Productos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...state.productos.map(
                (p) => _ProductoSelector(
                  producto: p,
                  cantidad: state.cantidades[p.productoId] ?? 0,
                  habilitado: !enviando,
                ),
              ),
            ],
          ),
        ),
        _ResumenBar(state: state, enviando: enviando),
      ],
    );
  }
}

class _ProductoSelector extends StatelessWidget {
  final Producto producto;
  final int cantidad;
  final bool habilitado;

  const _ProductoSelector({
    required this.producto,
    required this.cantidad,
    required this.habilitado,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PedidoBloc>();
    final cs = Theme.of(context).colorScheme;
    final seleccionado = cantidad > 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seleccionado ? cs.primary : cs.outlineVariant,
          width: seleccionado ? 1.6 : 1,
        ),
      ),
      color: seleccionado ? cs.primaryContainer.withAlpha(60) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '\$${producto.precioUnitario.toStringAsFixed(2)} · Stock: ${producto.stock}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
              onPressed: (habilitado && cantidad > 0)
                  ? () => bloc.add(
                      PedidoCantidadCambiada(producto: producto, delta: -1))
                  : null,
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$cantidad',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight:
                          cantidad > 0 ? FontWeight.bold : FontWeight.normal,
                      color: cantidad > 0
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              onPressed: (habilitado && cantidad < producto.stock)
                  ? () => bloc
                      .add(PedidoCantidadCambiada(producto: producto, delta: 1))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenBar extends StatelessWidget {
  final PedidoState state;
  final bool enviando;

  const _ResumenBar({required this.state, required this.enviando});

  @override
  Widget build(BuildContext context) {
    final items = state.cantidades.values.fold<int>(0, (acc, c) => acc + c);

    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$items ítem(s)',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      'Total: \$${state.totalEstimado.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: (state.puedeConfirmar && !enviando)
                    ? () =>
                        context.read<PedidoBloc>().add(const PedidoConfirmado())
                    : null,
                icon: enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(enviando ? 'Enviando…' : 'Confirmar pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
