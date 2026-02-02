import 'dart:io';

import 'package:agendamento_app/app/models/monthly_plan.dart';
import 'package:agendamento_app/app/models/service_item.dart';
import 'package:agendamento_app/app/models/user_profile.dart';
import 'package:agendamento_app/app/screens/login_page_cliente.dart';
import 'package:agendamento_app/app/screens/map_picker_page.dart';
import 'package:agendamento_app/app/screens/role_gate_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/supabase_storage_service.dart';
import 'package:agendamento_app/app/utils/availability_utils.dart';
import 'package:agendamento_app/app/utils/map_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _ServiceFormItem {
  final TextEditingController nameController;
  final TextEditingController priceController;

  _ServiceFormItem({String? name, String? price})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _PlanFormItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController servicesController;

  _PlanFormItem({String? name, String? price, String? services})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        servicesController = TextEditingController(text: services);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    servicesController.dispose();
  }
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _ruaController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _pixKeyController = TextEditingController();
  final TextEditingController _pixBankController = TextEditingController();
  final TextEditingController _locationLabelController =
      TextEditingController();
  String _pixKeyType = 'telefone';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppFirestoreService _firestoreService = AppFirestoreService();
  final SupabaseStorageService _storageService = SupabaseStorageService();
  final _formKey = GlobalKey<FormState>();

  bool _isBarber = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  File? _selectedImage;
  final List<_ServiceFormItem> _serviceItems = [
    _ServiceFormItem(name: 'Cabelo', price: '30'),
    _ServiceFormItem(name: 'Barba', price: '25'),
  ];
  final List<_PlanFormItem> _planItems = [];
  double? _locationLat;
  double? _locationLng;
  bool _isGeocoding = false;

  Map<String, dynamic> _currentEnderecoMap() {
    return {
      'bairro': _bairroController.text.trim(),
      'cidade': _cidadeController.text.trim(),
      'rua': _ruaController.text.trim(),
      'numero': _numeroController.text.trim(),
      'cep': _cepController.text.trim(),
    };
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _cepController.dispose();
    _pixKeyController.dispose();
    _pixBankController.dispose();
    _locationLabelController.dispose();
    for (final item in _serviceItems) {
      item.dispose();
    }
    for (final item in _planItems) {
      item.dispose();
    }
    super.dispose();
  }

  String? validateField(String? value, String fieldName, {int minLength = 1}) {
    if (value == null || value.isEmpty) {
      return "$fieldName não pode ser vazio";
    }
    if (value.length < minLength) {
      return "$fieldName deve ter no mínimo $minLength caracteres";
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  List<ServiceItem> _buildServices() {
    final services = <ServiceItem>[];
    for (final item in _serviceItems) {
      final name = item.nameController.text.trim();
      final priceText = item.priceController.text.trim();
      if (name.isEmpty || priceText.isEmpty) {
        continue;
      }
      final price = double.tryParse(priceText.replaceAll(',', '.')) ?? 0.0;
      services.add(ServiceItem(nome: name, preco: price));
    }
    return services;
  }

  List<MonthlyPlan> _buildMonthlyPlans() {
    final plans = <MonthlyPlan>[];
    for (final item in _planItems) {
      final name = item.nameController.text.trim();
      final priceText = item.priceController.text.trim();
      if (name.isEmpty || priceText.isEmpty) continue;
      final price = double.tryParse(priceText.replaceAll(',', '.')) ?? 0.0;
      final services = item.servicesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      plans.add(
        MonthlyPlan(
          id: name.toLowerCase().replaceAll(' ', '_'),
          name: name,
          price: price,
          services: services,
        ),
      );
    }
    return plans;
  }

  Future<BarbershopImageUploadResult?> _uploadBarbershopImage(
      String userId) async {
    if (_selectedImage == null) return null;
    return _storageService.uploadBarbershopImage(
      userId: userId,
      file: _selectedImage!,
    );
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As senhas não correspondem")),
      );
      return;
    }

    if (_isBarber) {
      if (_shopNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Informe o nome da barbearia")),
        );
        return;
      }
      if (_buildServices().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Adicione pelo menos um serviço")),
        );
        return;
      }
    }

    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este e-mail já está cadastrado. Faça login para continuar.',
            ),
          ),
        );
        return;
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return;

      final profile = UserProfile(
        uid: user.uid,
        role: _isBarber ? 'barber' : 'client',
        email: email,
        nome: _nameController.text.trim(),
        sobrenome: _surnameController.text.trim(),
        telefone: _phoneController.text.trim(),
      );

      await _firestoreService.createUserProfile(profile);

      if (_isBarber) {
        BarbershopImageUploadResult? uploadResult;
        if (_selectedImage != null) {
          try {
            uploadResult = await _uploadBarbershopImage(user.uid);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao enviar imagem: ${e.toString()}')),
            );
            return;
          }
        }
        final services = _buildServices();
        final endereco = {
          'bairro': _bairroController.text.trim(),
          'cidade': _cidadeController.text.trim(),
          'rua': _ruaController.text.trim(),
          'numero': _numeroController.text.trim(),
          'cep': _cepController.text.trim(),
        };
        final availability = buildAvailability(
          days: [1, 2, 3, 4, 5, 6],
          startHour: 9,
          endHour: 18,
        );

        await _firestoreService.createBarbershop(
          ownerId: user.uid,
          nome: _shopNameController.text.trim(),
          telefone: _phoneController.text.trim(),
          endereco: endereco,
          location: (_locationLat != null && _locationLng != null)
              ? {
                  'lat': _locationLat!,
                  'lng': _locationLng!,
                }
              : null,
          locationLabel: _locationLabelController.text.trim(),
          services: services,
          availability: availability,
          imageUrl: uploadResult?.imageUrl,
          imageThumbUrl: uploadResult?.thumbUrl,
          pixKey: _pixKeyController.text.trim().isEmpty
              ? null
              : _pixKeyController.text.trim(),
          pixKeyType: _pixKeyType,
          pixBankName: _pixBankController.text.trim().isEmpty
              ? null
              : _pixBankController.text.trim(),
          monthlyPlans: _buildMonthlyPlans(),
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleGatePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapAuthError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado: ${e.toString()}')),
      );
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'invalid-email':
        return 'E-mail inválido. Verifique e tente novamente.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 8 caracteres.';
      case 'operation-not-allowed':
        return 'Cadastro desativado. Entre em contato com o suporte.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      default:
        return 'Não foi possível criar a conta. ${e.message ?? ''}'.trim();
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
                        'Registro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SwitchListTile.adaptive(
                        value: _isBarber,
                        title: const Text('Sou barbeiro'),
                        onChanged: (value) {
                          setState(() {
                            _isBarber = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
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
                          isConfirm: false,
                        ),
                        validator: (value) =>
                            validateField(value, "Senha", minLength: 8),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration:
                            getAuthenticationInputDecoration("Confirme a Senha",
                                isPassword: true, isConfirm: true),
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
                            validateField(value, "Nome", minLength: 2),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _surnameController,
                        decoration:
                            getAuthenticationInputDecoration("Sobrenome"),
                        validator: (value) =>
                            validateField(value, "Sobrenome", minLength: 2),
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
                      if (_isBarber) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Dados da barbearia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _shopNameController,
                          decoration:
                              getAuthenticationInputDecoration("Nome da barbearia"),
                          validator: (value) =>
                              validateField(value, "Nome da barbearia"),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _bairroController,
                          decoration:
                              getAuthenticationInputDecoration("Bairro"),
                          validator: (value) => validateField(value, "Bairro"),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _cidadeController,
                          decoration:
                              getAuthenticationInputDecoration("Cidade"),
                          validator: (value) => validateField(value, "Cidade"),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _ruaController,
                          decoration: getAuthenticationInputDecoration("Rua"),
                          validator: (value) => validateField(value, "Rua"),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _numeroController,
                                decoration:
                                    getAuthenticationInputDecoration("Número"),
                                validator: (value) =>
                                    validateField(value, "Número"),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _cepController,
                                decoration: getAuthenticationInputDecoration("CEP"),
                                keyboardType: TextInputType.number,
                                validator: (value) => validateField(value, "CEP"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (!MapUtils.hasValidAddress(
                              _currentEnderecoMap(),
                            )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Preencha o endereço antes de selecionar o local.',
                                  ),
                                ),
                              );
                              return;
                            }
                            LatLng initial;
                            if (_locationLat != null && _locationLng != null) {
                              initial = LatLng(_locationLat!, _locationLng!);
                            } else {
                              final address =
                                  MapUtils.buildAddress(_currentEnderecoMap());
                              await _setGeocoding(true);
                              final geocoded =
                                  await MapUtils.geocodeAddress(address);
                              await _setGeocoding(false);
                              if (geocoded == null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Não foi possível localizar o endereço. Verifique e tente novamente.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              initial = geocoded;
                            }
                            final result = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MapPickerPage(initialPosition: initial),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                _locationLat = result.latitude;
                                _locationLng = result.longitude;
                              });
                            }
                          },
                          icon: const Icon(Icons.place_outlined),
                          label: const Text('Selecionar local exato no mapa'),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _locationLabelController,
                          decoration: getAuthenticationInputDecoration(
                            'Referência do local (opcional)',
                          ),
                        ),
                        if (_locationLat != null && _locationLng != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Local selecionado: '
                              '${_locationLat!.toStringAsFixed(6)}, '
                              '${_locationLng!.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pixKeyController,
                          decoration:
                              getAuthenticationInputDecoration("Chave Pix"),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _pixKeyType,
                          decoration: getAuthenticationInputDecoration(
                              "Tipo de chave Pix"),
                          items: const [
                            DropdownMenuItem(
                                value: 'telefone', child: Text('Telefone')),
                            DropdownMenuItem(
                                value: 'email', child: Text('E-mail')),
                            DropdownMenuItem(value: 'cpf', child: Text('CPF')),
                            DropdownMenuItem(
                                value: 'cnpj', child: Text('CNPJ')),
                            DropdownMenuItem(
                                value: 'aleatoria', child: Text('Aleatória')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _pixKeyType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pixBankController,
                          decoration: getAuthenticationInputDecoration(
                              "Banco (opcional)"),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Planos mensais',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._buildPlanFields(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _planItems.add(_PlanFormItem());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar plano'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: Text(_selectedImage == null
                              ? 'Selecionar imagem (opcional)'
                              : 'Imagem selecionada'),
                        ),
                        if (_selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Serviços e preços',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._buildServiceFields(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _serviceItems.add(_ServiceFormItem());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar serviço'),
                        ),
                      ],
                      const SizedBox(height: 24),
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

  List<Widget> _buildServiceFields() {
    final widgets = <Widget>[];
    for (int i = 0; i < _serviceItems.length; i++) {
      final item = _serviceItems[i];
      widgets.add(
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: item.nameController,
                decoration: getAuthenticationInputDecoration("Serviço"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: item.priceController,
                decoration: getAuthenticationInputDecoration("Preço"),
                keyboardType: TextInputType.number,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  item.dispose();
                  _serviceItems.removeAt(i);
                });
              },
            ),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Future<void> _setGeocoding(bool value) async {
    if (!mounted) return;
    setState(() {
      _isGeocoding = value;
    });
    if (value) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Buscando endereço...'),
              ],
            ),
          );
        },
      );
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  List<Widget> _buildPlanFields() {
    final widgets = <Widget>[];
    for (int i = 0; i < _planItems.length; i++) {
      final item = _planItems[i];
      widgets.add(
        Column(
          children: [
            TextFormField(
              controller: item.nameController,
              decoration: getAuthenticationInputDecoration('Nome do plano'),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: item.priceController,
              decoration: getAuthenticationInputDecoration('Valor do plano'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: item.servicesController,
              decoration: getAuthenticationInputDecoration(
                'Serviços do plano (separados por vírgula)',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    item.dispose();
                    _planItems.removeAt(i);
                  });
                },
              ),
            ),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  InputDecoration getAuthenticationInputDecoration(String label,
      {bool isPassword = false, bool isConfirm = false}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: isPassword
          ? IconButton(
              onPressed: () {
                setState(() {
                  if (isConfirm) {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  } else {
                    _obscurePassword = !_obscurePassword;
                  }
                });
              },
              icon: Icon(
                (isConfirm ? _obscureConfirmPassword : _obscurePassword)
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
            )
          : null,
    );
  }
}
