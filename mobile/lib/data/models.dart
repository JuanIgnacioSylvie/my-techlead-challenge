import 'package:equatable/equatable.dart';

double _asDouble(dynamic v) => (v as num).toDouble();

class Sesion extends Equatable {
  final String accessToken;
  final int usuarioId;
  final String nombreUsuario;
  final String nombreCompleto;

  const Sesion({
    required this.accessToken,
    required this.usuarioId,
    required this.nombreUsuario,
    required this.nombreCompleto,
  });

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
        accessToken: json['access_token'] as String,
        usuarioId: json['usuario_id'] as int,
        nombreUsuario: json['nombre_usuario'] as String,
        nombreCompleto: json['nombre_completo'] as String,
      );

  @override
  List<Object?> get props => [accessToken, usuarioId];
}

class Producto extends Equatable {
  final int productoId;
  final String sku;
  final String nombre;
  final String? descripcion;
  final double precioUnitario;
  final int stock;

  const Producto({
    required this.productoId,
    required this.sku,
    required this.nombre,
    required this.descripcion,
    required this.precioUnitario,
    required this.stock,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        productoId: json['producto_id'] as int,
        sku: json['sku'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String?,
        precioUnitario: _asDouble(json['precio_unitario']),
        stock: json['stock'] as int,
      );

  @override
  List<Object?> get props => [productoId, stock, precioUnitario];
}

class ProductosPage extends Equatable {
  final List<Producto> items;
  final int total;

  const ProductosPage({required this.items, required this.total});

  factory ProductosPage.fromJson(Map<String, dynamic> json) => ProductosPage(
        items: (json['items'] as List)
            .map((e) => Producto.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
      );

  @override
  List<Object?> get props => [items, total];
}

class Cliente extends Equatable {
  final int clienteId;
  final String nombre;
  final String? direccion;

  const Cliente(
      {required this.clienteId, required this.nombre, this.direccion});

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        clienteId: json['cliente_id'] as int,
        nombre: json['nombre'] as String,
        direccion: json['direccion'] as String?,
      );

  @override
  List<Object?> get props => [clienteId];
}

class PedidoCreado extends Equatable {
  final int pedidoId;
  final String estado;
  final double total;

  const PedidoCreado({
    required this.pedidoId,
    required this.estado,
    required this.total,
  });

  factory PedidoCreado.fromJson(Map<String, dynamic> json) => PedidoCreado(
        pedidoId: json['pedido_id'] as int,
        estado: json['estado'] as String,
        total: _asDouble(json['total']),
      );

  @override
  List<Object?> get props => [pedidoId];
}

class ResumenEstado extends Equatable {
  final String estado;
  final int cantidadPedidos;
  final double montoTotal;

  const ResumenEstado({
    required this.estado,
    required this.cantidadPedidos,
    required this.montoTotal,
  });

  factory ResumenEstado.fromJson(Map<String, dynamic> json) => ResumenEstado(
        estado: json['estado'] as String,
        cantidadPedidos: json['cantidad_pedidos'] as int,
        montoTotal: _asDouble(json['monto_total']),
      );

  @override
  List<Object?> get props => [estado, cantidadPedidos, montoTotal];
}

class Metricas extends Equatable {
  final List<ResumenEstado> resumenPorEstado;

  const Metricas({required this.resumenPorEstado});

  factory Metricas.fromJson(Map<String, dynamic> json) => Metricas(
        resumenPorEstado: (json['resumen_por_estado'] as List)
            .map((e) => ResumenEstado.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [resumenPorEstado];
}
