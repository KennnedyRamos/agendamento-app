import 'package:agendamento_app/app/utils/payment_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconhece formas atuais e legadas de pagamento no local', () {
    expect(isPayAtShopPayment('cash'), isTrue);
    expect(isPayAtShopPayment('pay_at_shop'), isTrue);
    expect(isPayAtShopPayment(' CASH '), isTrue);
  });

  test('nao confunde pagamento online com dinheiro no local', () {
    expect(isPayAtShopPayment('mercado_pago'), isFalse);
    expect(isPayAtShopPayment('pix'), isFalse);
    expect(isPayAtShopPayment(null), isFalse);
  });
}
