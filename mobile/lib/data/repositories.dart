import '../core/api_client.dart';
import '../core/token_storage.dart';
import 'models.dart';

const _prefix = '/api/v1';

class AuthRepository {
  final ApiClient api;
  final TokenStorage tokens;

  const AuthRepository({required this.api, required this.tokens});

  Future<Sesion> login(String username, String password) async {
    final data = await api.post(
      '$_prefix/auth/login',
      body: {'username': username, 'password': password},
    );
    final sesion = Sesion.fromJson(data as Map<String, dynamic>);
    await tokens.guardar(sesion.accessToken);
    return sesion;
  }

  Future<void> logout() => tokens.borrar();
}

class CatalogoRepository {
  final ApiClient api;

  const CatalogoRepository({required this.api});

  Future<ProductosPage> productos({String? nombre, int limit = 50}) async {
    final data = await api.get(
      '$_prefix/productos',
      query: {
        'limit': limit,
        if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
      },
    );
    return ProductosPage.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Cliente>> clientes() async {
    final data = await api.get('$_prefix/clientes');
    return (data as List)
        .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class PedidosRepository {
  final ApiClient api;

  const PedidosRepository({required this.api});

  Future<PedidoCreado> crear({
    required int clienteId,
    required Map<int, int> cantidadesPorProducto,
  }) async {
    final data = await api.post(
      '$_prefix/pedidos',
      body: {
        'cliente_id': clienteId,
        'detalle': cantidadesPorProducto.entries
            .map((e) => {'producto_id': e.key, 'cantidad': e.value})
            .toList(),
      },
    );
    return PedidoCreado.fromJson(data as Map<String, dynamic>);
  }
}

class MetricasRepository {
  final ApiClient api;

  const MetricasRepository({required this.api});

  Future<Metricas> obtener() async {
    final data = await api.get('$_prefix/metricas');
    return Metricas.fromJson(data as Map<String, dynamic>);
  }
}
