/// Error de API tipado: distingue fallas de red (sin respuesta HTTP)
/// de respuestas de error del backend (400/401/404/409/500).
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  /// true cuando no hubo respuesta HTTP (desconexión, timeout, DNS).
  bool get esErrorDeRed => statusCode == null;

  bool get esNoAutorizado => statusCode == 401;

  @override
  String toString() => message;
}
