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

class PedidoResumen extends Equatable {
  final int pedidoId;
  final String clienteNombre;
  final String estado;
  final double total;
  final DateTime fechaCreacion;

  const PedidoResumen({
    required this.pedidoId,
    required this.clienteNombre,
    required this.estado,
    required this.total,
    required this.fechaCreacion,
  });

  factory PedidoResumen.fromJson(Map<String, dynamic> json) => PedidoResumen(
        pedidoId: json['pedido_id'] as int,
        clienteNombre: json['cliente_nombre'] as String,
        estado: json['estado'] as String,
        total: _asDouble(json['total']),
        fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      );

  @override
  List<Object?> get props => [pedidoId, estado, total];
}

class PedidosPage extends Equatable {
  final List<PedidoResumen> items;
  final int total;

  const PedidosPage({required this.items, required this.total});

  factory PedidosPage.fromJson(Map<String, dynamic> json) => PedidosPage(
        items: (json['items'] as List)
            .map((e) => PedidoResumen.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
      );

  @override
  List<Object?> get props => [items, total];
}

class RenglonPedido extends Equatable {
  final int productoId;
  final String sku;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  const RenglonPedido({
    required this.productoId,
    required this.sku,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory RenglonPedido.fromJson(Map<String, dynamic> json) => RenglonPedido(
        productoId: json['producto_id'] as int,
        sku: json['sku'] as String,
        nombre: json['nombre'] as String,
        cantidad: json['cantidad'] as int,
        precioUnitario: _asDouble(json['precio_unitario']),
        subtotal: _asDouble(json['subtotal']),
      );

  @override
  List<Object?> get props => [productoId, cantidad];
}

class PedidoDetalle extends Equatable {
  final int pedidoId;
  final String clienteNombre;
  final String usuarioNombre;
  final String estado;
  final double total;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final List<RenglonPedido> renglones;

  const PedidoDetalle({
    required this.pedidoId,
    required this.clienteNombre,
    required this.usuarioNombre,
    required this.estado,
    required this.total,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    required this.renglones,
  });

  factory PedidoDetalle.fromJson(Map<String, dynamic> json) => PedidoDetalle(
        pedidoId: json['pedido_id'] as int,
        clienteNombre: json['cliente_nombre'] as String,
        usuarioNombre: json['usuario_nombre'] as String,
        estado: json['estado'] as String,
        total: _asDouble(json['total']),
        fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
        fechaActualizacion:
            DateTime.parse(json['fecha_actualizacion'] as String),
        renglones: (json['detalle'] as List)
            .map((e) => RenglonPedido.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [pedidoId, estado, fechaActualizacion];
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
