import 'package:flutter/material.dart';

/// Presentación de los estados de pedido. La API expone el valor técnico
/// del CHECK de SQL Server (ej. "EnPreparacion"); acá se traduce a una
/// etiqueta legible con color e ícono consistentes en toda la app.
class EstadoPedidoUi {
  final String etiqueta;
  final Color color;
  final IconData icono;

  /// Posición en el ciclo de vida del pedido (para ordenar listados).
  final int orden;

  const EstadoPedidoUi._(this.etiqueta, this.color, this.icono, this.orden);

  static const _porEstado = <String, EstadoPedidoUi>{
    'Pendiente': EstadoPedidoUi._(
        'Pendiente', Color(0xFFF57C00), Icons.schedule_outlined, 0),
    'EnPreparacion': EstadoPedidoUi._(
        'En preparación', Color(0xFF1976D2), Icons.inventory_2_outlined, 1),
    'Enviado': EstadoPedidoUi._(
        'Enviado', Color(0xFF00838F), Icons.local_shipping_outlined, 2),
    'Entregado': EstadoPedidoUi._(
        'Entregado', Color(0xFF2E7D32), Icons.check_circle_outline, 3),
    'Cancelado': EstadoPedidoUi._(
        'Cancelado', Color(0xFFC62828), Icons.cancel_outlined, 4),
  };

  factory EstadoPedidoUi.de(String estado) =>
      _porEstado[estado] ??
      EstadoPedidoUi._(estado, const Color(0xFF616161), Icons.help_outline, 99);
}
