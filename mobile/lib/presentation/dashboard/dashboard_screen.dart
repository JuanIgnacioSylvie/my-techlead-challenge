import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/estados.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../login/auth_bloc.dart';
import '../login/login_screen.dart';
import '../pedido/pedido_screen.dart';
import '../pedidos/pedidos_screen.dart';
import 'dashboard_bloc.dart';

/// Pantalla 2: catálogo con búsqueda + métricas de operación.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardBloc(
        catalogoRepository: context.read<CatalogoRepository>(),
        metricasRepository: context.read<MetricasRepository>(),
      )..add(const DashboardRequested()),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _cerrarSesion() {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.select<AuthBloc, Sesion?>(
      (bloc) => switch (bloc.state) {
        AuthAuthenticated(:final sesion) => sesion,
        _ => null,
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
            sesion == null ? 'Catálogo' : 'Hola, ${sesion.nombreCompleto}'),
        actions: [
          IconButton(
            tooltip: 'Pedidos',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () async {
              final bloc = context.read<DashboardBloc>();
              final busqueda = switch (bloc.state) {
                DashboardLoaded(:final busqueda) => busqueda,
                _ => '',
              };
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PedidosScreen()),
              );
              // Al volver: un cambio de estado (p.ej. cancelar) pudo
              // alterar stock y métricas.
              bloc.add(DashboardRequested(busqueda: busqueda));
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is! DashboardLoaded || state.productos.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Nuevo pedido'),
            onPressed: () async {
              final bloc = context.read<DashboardBloc>();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PedidoScreen(productos: state.productos),
                ),
              );
              // Al volver: stock y métricas pudieron cambiar
              bloc.add(DashboardRequested(busqueda: state.busqueda));
            },
          );
        },
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          return switch (state) {
            DashboardLoading() =>
              const Center(child: CircularProgressIndicator()),
            DashboardError() => _ErrorView(
                mensaje: state.mensaje,
                esNoAutorizado: state.esNoAutorizado,
                onReintentar: () => context.read<DashboardBloc>().add(
                    DashboardRequested(busqueda: _busquedaController.text)),
                onIrALogin: _cerrarSesion,
              ),
            DashboardLoaded() => RefreshIndicator(
                onRefresh: () async => context
                    .read<DashboardBloc>()
                    .add(DashboardRequested(busqueda: state.busqueda)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MetricasSection(metricas: state.metricas),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _busquedaController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (texto) => context
                          .read<DashboardBloc>()
                          .add(DashboardRequested(busqueda: texto.trim())),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto por nombre…',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: state.busqueda.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _busquedaController.clear();
                                  context
                                      .read<DashboardBloc>()
                                      .add(const DashboardRequested());
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.total} producto(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (state.productos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                            child: Text('Sin resultados para la búsqueda.')),
                      )
                    else
                      ...state.productos.map((p) => _ProductoTile(producto: p)),
                    const SizedBox(height: 80), // aire para el FAB
                  ],
                ),
              ),
          };
        },
      ),
    );
  }
}

class _MetricasSection extends StatelessWidget {
  final Metricas metricas;

  const _MetricasSection({required this.metricas});

  @override
  Widget build(BuildContext context) {
    if (metricas.resumenPorEstado.isEmpty) return const SizedBox.shrink();

    // Orden por ciclo de vida del pedido, no alfabético
    final resumen = [...metricas.resumenPorEstado]..sort(
        (a, b) => EstadoPedidoUi.de(a.estado)
            .orden
            .compareTo(EstadoPedidoUi.de(b.estado).orden),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights_outlined,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Operación de hoy',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: resumen.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = resumen[i];
              final ui = EstadoPedidoUi.de(r.estado);
              return Container(
                width: 150,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ui.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ui.color.withAlpha(80)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ui.icono, size: 16, color: ui.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ui.etiqueta,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: ui.color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.cantidadPedidos} pedido${r.cantidadPedidos == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '\$${r.montoTotal.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductoTile extends StatelessWidget {
  final Producto producto;

  const _ProductoTile({required this.producto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (colorStock, textoStock) = switch (producto.stock) {
      0 => (const Color(0xFFC62828), 'Sin stock'),
      < 20 => (const Color(0xFFF57C00), 'Stock bajo: ${producto.stock}'),
      _ => (const Color(0xFF2E7D32), 'Stock: ${producto.stock}'),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Text(
                producto.nombre[0].toUpperCase(),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    producto.sku,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorStock.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colorStock.withAlpha(80)),
                    ),
                    child: Text(
                      textoStock,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colorStock),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${producto.precioUnitario.toStringAsFixed(2)}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String mensaje;
  final bool esNoAutorizado;
  final VoidCallback onReintentar;
  final VoidCallback onIrALogin;

  const _ErrorView({
    required this.mensaje,
    required this.esNoAutorizado,
    required this.onReintentar,
    required this.onIrALogin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              esNoAutorizado
                  ? Icons.lock_clock_outlined
                  : Icons.wifi_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (esNoAutorizado)
              FilledButton.icon(
                onPressed: onIrALogin,
                icon: const Icon(Icons.login),
                label: const Text('Volver a iniciar sesión'),
              )
            else
              FilledButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
          ],
        ),
      ),
    );
  }
}
