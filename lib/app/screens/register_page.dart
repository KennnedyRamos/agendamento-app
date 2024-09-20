import 'package:agendamento_app/_colors/my_colors.dart';
import 'package:agendamento_app/app/screens/welcome_page.dart'; // Certifique-se de que o caminho está correto
import 'package:agendamento_app/app/screens/login_page_cliente.dart';
import 'package:agendamento_app/app/services/firestore_service.dart';
import 'package:agendamento_app/app/models/cadastro_cliente_models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  // Função de validação reutilizável
  String? validateField(String? value, String fieldName, {int minLength = 1}) {
    if (value == null || value.isEmpty) {
      return "$fieldName não pode ser vazio";
    }
    if (value.length < minLength) {
      return "$fieldName deve ter no mínimo $minLength caracteres";
    }
    return null;
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("As senhas não correspondem")),
        );
        return;
      }

      try {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (userCredential.user != null) {
          CadastroClienteModels cliente = CadastroClienteModels(
            id: userCredential.user!.uid,
            email: _emailController.text,
            nome: _nameController.text,
            sobrenome: _surnameController.text,
            telefone: _phoneController.text,
          );

          await _firestoreService.saveCliente(cliente);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const WelcomePage(),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar conta: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.azulEscuroTon01,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MyColors.azulClaroTon01,
                  MyColors.azulClaroTon03,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset("assets/logo1.png", height: 190),
                      const Text(
                        "Registro",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        decoration: getAuthenticationInputDecoration("Email"),
                        validator: (value) =>
                            validateField(value, "Email", minLength: 5),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: getAuthenticationInputDecoration("Senha"),
                        validator: (value) =>
                            validateField(value, "Senha", minLength: 8),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: getAuthenticationInputDecoration(
                            "Confirme a Senha"),
                        validator: (value) => validateField(
                            value, "Confirmação da Senha",
                            minLength: 8),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _nameController,
                        decoration: getAuthenticationInputDecoration("Nome"),
                        keyboardType: TextInputType.name,
                        validator: (value) =>
                            validateField(value, "Nome", minLength: 5),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _surnameController,
                        decoration:
                            getAuthenticationInputDecoration("Sobrenome"),
                        validator: (value) =>
                            validateField(value, "Sobrenome", minLength: 5),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _phoneController,
                        decoration:
                            getAuthenticationInputDecoration("Telefone"),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            validateField(value, "Telefone", minLength: 10),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _register,
                        child: const Text("Cadastrar"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text("Já tem uma conta? Entrar"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration getAuthenticationInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: MyColors.azulEscuroTon01),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: MyColors.azulEscuroTon01),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: MyColors.azulEscuroTon01),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: MyColors.azulEscuroTon01),
      ),
    );
  }
}
