import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agendamento_app/app/models/cadastro_cliente_models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Função para salvar o cliente no Firestore
  Future<void> saveCliente(CadastroClienteModels cliente) async {
    try {
      await _db.collection('clientes').doc(cliente.id).set(cliente.toMap());
    } catch (e) {
      print('Erro ao salvar cliente: $e');
      throw Exception('Erro ao salvar os dados do cliente.');
    }
  }

  // Função para buscar cliente por ID
  Future<CadastroClienteModels?> getClienteById(String id) async {
    try {
      DocumentSnapshot doc = await _db.collection('clientes').doc(id).get();
      if (doc.exists) {
        return CadastroClienteModels.fromMap(
            doc.data() as Map<String, dynamic>);
      } else {
        return null;
      }
    } catch (e) {
      print('Erro ao buscar cliente: $e');
      return null;
    }
  }

  // Função para buscar todos os clientes (caso queira exibir uma lista)
  Future<List<CadastroClienteModels>> getAllClientes() async {
    try {
      QuerySnapshot querySnapshot = await _db.collection('clientes').get();
      return querySnapshot.docs.map((doc) {
        return CadastroClienteModels.fromMap(
            doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Erro ao buscar clientes: $e');
      return [];
    }
  }
}
