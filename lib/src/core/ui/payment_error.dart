import 'package:dio/dio.dart';

String paymentErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (error.response?.statusCode == 422 && data is Map) {
      final errors = data['errors'];
      final messages = <String>[];
      if (errors is Map) {
        for (final value in errors.values) {
          for (final item in value is List ? value : [value]) {
            if (item is String && item.trim().isNotEmpty)
              messages.add(item.trim());
          }
        }
      }
      if (messages.isEmpty && data['message'] is String) {
        messages.add((data['message'] as String).trim());
      }
      final message = messages.toSet().take(3).join('\n');
      if (message.isNotEmpty &&
          !message.contains('<') &&
          !message.contains('SQLSTATE')) {
        return message.length > 500 ? '${message.substring(0, 500)}…' : message;
      }
      return 'No se pudo generar el pago. Revisa el monto, la placa y tus datos de facturación. Si están correctos, contacta a soporte (código 422).';
    }
    if (error.response?.statusCode == 401)
      return 'Tu sesión venció. Vuelve a iniciar sesión.';
    if (error.response == null)
      return 'No pudimos confirmar la solicitud. Revisa tu conexión y los movimientos pendientes antes de volver a intentar.';
  }
  return 'No se pudo abrir el pago. Revisa tus movimientos pendientes antes de volver a intentar.';
}
