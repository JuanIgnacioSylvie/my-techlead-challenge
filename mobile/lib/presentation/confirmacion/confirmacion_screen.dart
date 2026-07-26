import 'package:flutter/material.dart';

import '../../core/estados.dart';
import '../../data/models.dart';

/// Pantalla 4: resultado de la transacción (éxito o error).
class ConfirmacionScreen extends StatelessWidget {
  final PedidoCreado? resultado;
  final String? mensajeError;

  const ConfirmacionScreen({super.key, required PedidoCreado this.resultado})
      : mensajeError = null;

  const ConfirmacionScreen.error({super.key, required String mensaje})
      : resultado = null,
        mensajeError = mensaje;

  bool get exito => resultado != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar:
          AppBar(title: Text(exito ? 'Pedido confirmado' : 'Pedido rechazado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (exito ? Colors.green.shade600 : colorScheme.error)
                      .withAlpha(20),
                ),
                child: Icon(
                  exito ? Icons.check_circle_outline : Icons.error_outline,
                  size: 88,
                  color: exito ? Colors.green.shade600 : colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              if (exito) ...[
                Text(
                  'Pedido #${resultado!.pedidoId} registrado',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _EstadoChip(estado: resultado!.estado),
                const SizedBox(height: 12),
                Text(
                  'Total: \$${resultado!.total.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ] else ...[
                Text(
                  'No se pudo registrar el pedido',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  mensajeError ?? 'Error desconocido.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 32),
              if (exito)
                FilledButton.icon(
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Volver al catálogo'),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                )
              else ...[
                FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Corregir pedido'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
                TextButton(
                  child: const Text('Volver al catálogo'),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final ui = EstadoPedidoUi.de(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ui.color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ui.icono, size: 18, color: ui.color),
          const SizedBox(width: 6),
          Text(
            ui.etiqueta,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: ui.color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
