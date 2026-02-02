class ServiceItem {
  final String nome;
  final double preco;

  ServiceItem({required this.nome, required this.preco});

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'preco': preco,
    };
  }

  static ServiceItem fromMap(Map<String, dynamic> map) {
    final precoValue = map['preco'];
    final preco =
        precoValue is int ? precoValue.toDouble() : (precoValue ?? 0.0);
    return ServiceItem(
      nome: map['nome'] ?? '',
      preco: preco,
    );
  }
}
