import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_exception.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

// ----- Eventos -----

sealed class PedidosEvent extends Equatable {
  const PedidosEvent();

  @override
  List<Object?> get props => [];
}

/// Carga el listado; [estadoFiltro] en null trae todos.
class PedidosSolicitados extends PedidosEvent {
  final String? estadoFiltro;

  const PedidosSolicitados({this.estadoFiltro});

  @override
  List<Object?> get props => [estadoFiltro];
}

// ----- Estados -----

sealed class PedidosState extends Equatable {
  const PedidosState();

  @override
  List<Object?> get props => [];
}

class PedidosLoading extends PedidosState {
  final String? estadoFiltro;

  const PedidosLoading({this.estadoFiltro});

  @override
  List<Object?> get props => [estadoFiltro];
}

class PedidosLoaded extends PedidosState {
  final List<PedidoResumen> pedidos;
  final int total;
  final String? estadoFiltro;

  const PedidosLoaded({
    required this.pedidos,
    required this.total,
    this.estadoFiltro,
  });

  @override
  List<Object?> get props => [pedidos, total, estadoFiltro];
}

class PedidosError extends PedidosState {
  final String mensaje;
  final String? estadoFiltro;

  const PedidosError(this.mensaje, {this.estadoFiltro});

  @override
  List<Object?> get props => [mensaje, estadoFiltro];
}

// ----- Bloc -----

class PedidosBloc extends Bloc<PedidosEvent, PedidosState> {
  final PedidosRepository pedidosRepository;

  PedidosBloc({required this.pedidosRepository})
      : super(const PedidosLoading()) {
    on<PedidosSolicitados>(_onSolicitados);
  }

  Future<void> _onSolicitados(
    PedidosSolicitados event,
    Emitter<PedidosState> emit,
  ) async {
    emit(PedidosLoading(estadoFiltro: event.estadoFiltro));
    try {
      final page = await pedidosRepository.listar(estado: event.estadoFiltro);
      emit(PedidosLoaded(
        pedidos: page.items,
        total: page.total,
        estadoFiltro: event.estadoFiltro,
      ));
    } on ApiException catch (e) {
      emit(PedidosError(e.message, estadoFiltro: event.estadoFiltro));
    }
  }
}
