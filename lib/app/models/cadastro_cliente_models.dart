class CadastroClienteModels {
  String id;
  String nome;
  String sobrenome;
  String email;
  String telefone;

  CadastroClienteModels({
    required this.id,
    required this.nome,
    required this.sobrenome,
    required this.email,
    required this.telefone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'sobrenome': sobrenome,
      'email': email,
      'telefone': telefone,
    };
  }

  static CadastroClienteModels fromMap(Map<String, dynamic> map) {
    return CadastroClienteModels(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      sobrenome: map['sobrenome'] ?? '',
      email: map['email'] ?? '',
      telefone: map['telefone'] ?? 0,
    );
  }
}
