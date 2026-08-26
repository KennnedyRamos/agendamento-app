class UserProfile {
  final String uid;
  final String role; // client | barber
  final String nome;
  final String sobrenome;
  final String email;
  final String telefone;

  UserProfile({
    required this.uid,
    required this.role,
    required this.nome,
    required this.sobrenome,
    required this.email,
    required this.telefone,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'nome': nome,
      'sobrenome': sobrenome,
      'email': email,
      'telefone': telefone,
    };
  }

  static UserProfile fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      role: map['role'] ?? 'client',
      nome: map['nome'] ?? '',
      sobrenome: map['sobrenome'] ?? '',
      email: map['email'] ?? '',
      telefone: map['telefone'] ?? '',
    );
  }
}
