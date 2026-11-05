import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';

void main() {
  test('native result cannot mark an order completed', () {
    expect(projectOrder('SUCCEEDED', 'PROCESSING'), OrderAppState.crediting);
    expect(projectOrder('SUCCEEDED', 'EXCEPTION'), OrderAppState.crediting);
    expect(projectOrder('SUCCEEDED', 'SUCCEEDED'), OrderAppState.completed);
  });
  test('projects all seven server states and rejects unknown', () {
    expect(
      projectOrder('PENDING', 'NOT_STARTED'),
      OrderAppState.pendingPayment,
    );
    expect(projectOrder('PROCESSING', 'NOT_STARTED'), OrderAppState.paying);
    expect(projectOrder('FAILED', 'NOT_STARTED'), OrderAppState.paymentFailed);
    expect(projectOrder('CANCELED', 'NOT_STARTED'), OrderAppState.canceled);
    expect(projectOrder('CLOSED', 'NOT_STARTED'), OrderAppState.closed);
    expect(() => projectOrder('UNKNOWN', 'NOT_STARTED'), throwsFormatException);
  });
}
