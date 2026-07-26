import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_exception.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

// ----- Eventos -----

sealed class PedidoDetalleEvent extends Equatable {
  const PedidoDetalleEvent();

  @override
  List<Object?> get props => [];
}

class PedidoDetalleSolicitado extends PedidoDetalleEvent {
  const PedidoDetalleSolicitado();
}

class PedidoEstadoCambiado extends PedidoDetalleEvent {
  final String nuevoEstado;

  const PedidoEstadoCambiado(this.nuevoEstado);

  @override
  List<Object?> get props => [nuevoEstado];
}

// ----- Estado -----

enum DetalleStatus { cargando, listo, actualizando, error }

class PedidoDetalleState extends Equatable {
  final DetalleStatus status;
  final PedidoDetalle? pedido;

  /// Error de carga (pantalla) o de transición (snackbar), según status.
  final String? error;

  /// true cuando el último cambio de estado se aplicó bien (para feedback).
  final bool cambioExitoso;

  const PedidoDetalleState({
    this.status = DetalleStatus.cargando,
    this.pedido,
    this.error,
    this.cambioExitoso = false,
  });

  PedidoDetalleState copyWith({
    DetalleStatus? status,
    PedidoDetalle? pedido,
    String? error,
    bool cambioExitoso = false,
  }) {
    return PedidoDetalleState(
      status: status ?? this.status,
      pedido: pedido ?? this.pedido,
      error: error,
      cambioExitoso: cambioExitoso,
    );
  }

  @override
  List<Object?> get props => [status, pedido, error, cambioExitoso];
}

// ----- Bloc -----

class PedidoDetalleBloc extends Bloc<PedidoDetalleEvent, PedidoDetalleState> {
  final PedidosRepository pedidosRepository;
  final int pedidoId;

  PedidoDetalleBloc({required this.pedidosRepository, required this.pedidoId})
      : super(const PedidoDetalleState()) {
    on<PedidoDetalleSolicitado>(_onSolicitado);
    on<PedidoEstadoCambiado>(_onEstadoCambiado);
  }

  Future<void> _onSolicitado(
    PedidoDetalleSolicitado event,
    Emitter<PedidoDetalleState> emit,
  ) async {
    emit(state.copyWith(status: DetalleStatus.cargando));
    try {
      final pedido = await pedidosRepository.detalle(pedidoId);
      emit(state.copyWith(status: DetalleStatus.listo, pedido: pedido));
    } on ApiException catch (e) {
      emit(state.copyWith(status: DetalleStatus.error, error: e.message));
    }
  }

  Future<void> _onEstadoCambiado(
    PedidoEstadoCambiado event,
    Emitter<PedidoDetalleState> emit,
  ) async {
    emit(state.copyWith(status: DetalleStatus.actualizando));
    try {
      final pedido = await pedidosRepository.actualizarEstado(
        pedidoId,
        event.nuevoEstado,
      );
      emit(state.copyWith(
        status: DetalleStatus.listo,
        pedido: pedido,
        cambioExitoso: true,
      ));
    } on ApiException catch (e) {
      // La transición falló (p.ej. regla del SP): el pedido queda como estaba
      emit(state.copyWith(status: DetalleStatus.listo, error: e.message));
    }
  }
}
