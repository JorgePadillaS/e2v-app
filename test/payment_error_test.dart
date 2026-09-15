import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxvolt_app/src/core/ui/payment_error.dart';

void main() {
  DioException rejected(dynamic body) => DioException(
    requestOptions: RequestOptions(path: 'wallet/libelula/checkout'),
    response: Response(
      requestOptions: RequestOptions(),
      statusCode: 422,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );
  test('Checkout exposes validation messages instead of Dio internals', () {
    expect(
      paymentErrorMessage(
        rejected({
          'errors': {
            'placa': ['Ingresa una placa válida.'],
          },
        }),
      ),
      'Ingresa una placa válida.',
    );
    expect(
      paymentErrorMessage(rejected({'message': 'No se pudo crear el pago'})),
      'No se pudo crear el pago',
    );
    expect(
      paymentErrorMessage(rejected('<html>Error</html>')),
      isNot(contains('DioException')),
    );
  });
}
