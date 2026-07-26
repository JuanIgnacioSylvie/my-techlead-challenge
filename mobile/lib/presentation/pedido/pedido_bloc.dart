import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_exception.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

// ----- Eventos -----

sealed class PedidoEvent extends Equatable {
  const PedidoEvent();

  @override
  List<Object?> get props => [];
}

class PedidoIniciado extends PedidoEvent {
  const PedidoIniciado();
}

class PedidoClienteSeleccionado extends PedidoEvent {
  final Cliente cliente;

  const PedidoClienteSeleccionado(this.cliente);

  @override
  List<Object?> get props => [cliente];
}

/// Suma [delta] (+1 / -1) a la cantidad del producto; en 0 sale del carrito.
class PedidoCantidadCambiada extends PedidoEvent {
  final Producto producto;
  final int delta;

  const PedidoCantidadCambiada({required this.producto, required this.delta});

  @override
  List<Object?> get props => [producto, delta];
}

class PedidoConfirmado extends PedidoEvent {
  const PedidoConfirmado();
}

// ----- Estado -----

enum PedidoStatus { cargandoClientes, listo, enviando, exito, errorCarga }

class PedidoState extends Equatable {
  final PedidoStatus status;
  final List<Cliente> clientes;
  final Cliente? clienteSeleccionado;

  /// productoId -> cantidad
  final Map<int, int> cantidades;
  final List<Producto> productos;
  final PedidoCreado? resultado;
  final String? error;

  const PedidoState({
    this.status = PedidoStatus.cargandoClientes,
    this.clientes = const [],
    this.clienteSeleccionado,
    this.cantidades = const {},
    this.productos = const [],
    this.resultado,
    this.error,
  });

  double get totalEstimado => cantidades.entries.fold(0, (acc, e) {
        final producto = productos.firstWhere((p) => p.productoId == e.key);
        return acc + producto.precioUnitario * e.value;
      });

  bool get puedeConfirmar =>
      clienteSeleccionado != null &&
      cantidades.isNotEmpty &&
      status == PedidoStatus.listo;

  PedidoState copyWith({
    PedidoStatus? status,
    List<Cliente>? clientes,
    Cliente? clienteSeleccionado,
    Map<int, int>? cantidades,
    List<Producto>? productos,
    PedidoCreado? resultado,
    String? error,
  }) {
    return PedidoState(
      status: status ?? this.status,
      clientes: clientes ?? this.clientes,
      clienteSeleccionado: clienteSeleccionado ?? this.clienteSeleccionado,
      cantidades: cantidades ?? this.cantidades,
      productos: productos ?? this.productos,
      resultado: resultado ?? this.resultado,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        clientes,
        clienteSeleccionado,
        cantidades,
        productos,
        resultado,
        error
      ];
}

// ----- Bloc -----

class PedidoBloc extends Bloc<PedidoEvent, PedidoState> {
  final CatalogoRepository catalogoRepository;
  final PedidosRepository pedidosRepository;

  PedidoBloc({
    required this.catalogoRepository,
    required this.pedidosRepository,
    required List<Producto> productos,
  }) : super(PedidoState(productos: productos)) {
    on<PedidoIniciado>(_onIniciado);
    on<PedidoClienteSeleccionado>(
      (event, emit) => emit(state.copyWith(clienteSeleccionado: event.cliente)),
    );
    on<PedidoCantidadCambiada>(_onCantidadCambiada);
    on<PedidoConfirmado>(_onConfirmado);
  }

  Future<void> _onIniciado(
      PedidoIniciado event, Emitter<PedidoState> emit) async {
    emit(state.copyWith(status: PedidoStatus.cargandoClientes));
    try {
      final clientes = await catalogoRepository.clientes();
      emit(state.copyWith(status: PedidoStatus.listo, clientes: clientes));
    } on ApiException catch (e) {
      emit(state.copyWith(status: PedidoStatus.errorCarga, error: e.message));
    }
  }

  void _onCantidadCambiada(
    PedidoCantidadCambiada event,
    Emitter<PedidoState> emit,
  ) {
    final id = event.producto.productoId;
    final actual = state.cantidades[id] ?? 0;
    final nueva = (actual + event.delta).clamp(0, event.producto.stock);

    final cantidades = Map<int, int>.from(state.cantidades);
    if (nueva == 0) {
      cantidades.remove(id);
    } else {
      cantidades[id] = nueva;
    }
    emit(state.copyWith(cantidades: cantidades));
  }

  Future<void> _onConfirmado(
    PedidoConfirmado event,
    Emitter<PedidoState> emit,
  ) async {
    if (!state.puedeConfirmar) return;

    emit(state.copyWith(status: PedidoStatus.enviando));
    try {
      final resultado = await pedidosRepository.crear(
        clienteId: state.clienteSeleccionado!.clienteId,
        cantidadesPorProducto: state.cantidades,
      );
      emit(state.copyWith(status: PedidoStatus.exito, resultado: resultado));
    } on ApiException catch (e) {
      // Vuelve a "listo" conservando el carrito para poder reintentar
      emit(state.copyWith(status: PedidoStatus.listo, error: e.message));
    }
  }
}
