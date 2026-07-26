import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_exception.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

// ----- Eventos -----

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Carga (o recarga) catálogo y métricas; [busqueda] filtra por nombre.
class DashboardRequested extends DashboardEvent {
  final String busqueda;

  const DashboardRequested({this.busqueda = ''});

  @override
  List<Object?> get props => [busqueda];
}

// ----- Estados -----

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final List<Producto> productos;
  final int total;
  final Metricas metricas;
  final String busqueda;

  const DashboardLoaded({
    required this.productos,
    required this.total,
    required this.metricas,
    required this.busqueda,
  });

  @override
  List<Object?> get props => [productos, total, metricas, busqueda];
}

class DashboardError extends DashboardState {
  final String mensaje;
  final bool esNoAutorizado;

  const DashboardError(this.mensaje, {this.esNoAutorizado = false});

  @override
  List<Object?> get props => [mensaje, esNoAutorizado];
}

// ----- Bloc -----

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final CatalogoRepository catalogoRepository;
  final MetricasRepository metricasRepository;

  DashboardBloc({
    required this.catalogoRepository,
    required this.metricasRepository,
  }) : super(const DashboardLoading()) {
    on<DashboardRequested>(_onRequested);
  }

  Future<void> _onRequested(
    DashboardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    try {
      // Catálogo y métricas en paralelo: una sola espera para el usuario
      final resultados = await Future.wait([
        catalogoRepository.productos(nombre: event.busqueda),
        metricasRepository.obtener(),
      ]);
      final pagina = resultados[0] as ProductosPage;
      final metricas = resultados[1] as Metricas;

      emit(DashboardLoaded(
        productos: pagina.items,
        total: pagina.total,
        metricas: metricas,
        busqueda: event.busqueda,
      ));
    } on ApiException catch (e) {
      emit(DashboardError(e.message, esNoAutorizado: e.esNoAutorizado));
    }
  }
}
