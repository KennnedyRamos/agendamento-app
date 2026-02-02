import 'package:agendamento_app/app/screens/register_page.dart';
import 'package:agendamento_app/app/screens/role_gate_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _navigating = false;

  // Função reutilizável de validação
  String? validateField(String? value, String fieldName, {int minLength = 1}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe $fieldName.';
    }
    if (trimmed.length < minLength) {
      return '$fieldName deve ter pelo menos $minLength caracteres.';
    }
    return null;
  }

  Future<void> _login() async {
    if (_isLoading) return;
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          if (!mounted || _navigating) return;
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RoleGatePage()),
            );
          });
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Erro ao fazer login.';
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'Usuário não encontrado. Verifique o e-mail.';
            break;
          case 'wrong-password':
            errorMessage = 'Senha inválida. Tente novamente.';
            break;
          case 'invalid-email':
            errorMessage = 'E-mail inválido. Verifique o formato.';
            break;
          case 'too-many-requests':
            errorMessage =
                'Muitas tentativas. Tente novamente em alguns minutos.';
            break;
          case 'operation-not-allowed':
            errorMessage =
                'Operação não permitida. Contate o suporte.';
            break;
          case 'network-request-failed':
            errorMessage = 'Sem conexão. Verifique sua internet.';
            break;
          case 'invalid-credential':
            errorMessage = 'E-mail ou senha inválidos.';
            break;
          default:
            errorMessage = 'Erro desconhecido: ${e.message}';
            break;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer login: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.primary.withValues(alpha: 0.08),
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
                      Text(
                        'BarberShop',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
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
                        obscureText: _obscurePassword,
                        decoration: getAuthenticationInputDecoration(
                          "Senha",
                          isPassword: true,
                        ),
                        validator: (value) =>
                            validateField(value, "Senha", minLength: 8),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Entrar"),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ResetPasswordPage(),
                            ),
                          );
                        },
                        child: const Text('Redefinir senha'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text('Criar uma conta'),
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

  InputDecoration getAuthenticationInputDecoration(String label,
      {bool isPassword = false}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: isPassword
          ? IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
            )
          : null,
    );
  }
}


