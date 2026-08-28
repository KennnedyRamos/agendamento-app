bool isPayAtShopPayment(Object? value) {
  final method = value?.toString().trim().toLowerCase() ?? '';
  return method == 'cash' || method == 'pay_at_shop';
}
