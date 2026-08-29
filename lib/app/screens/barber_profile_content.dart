import 'dart:io';

import 'package:agendamento_app/app/models/monthly_plan.dart';
import 'package:agendamento_app/app/models/service_item.dart';
import 'package:agendamento_app/app/screens/map_picker_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/barbershop_logo_service.dart';
import 'package:agendamento_app/app/utils/availability_utils.dart';
import 'package:agendamento_app/app/utils/map_utils.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:agendamento_app/app/widgets/legal_links_card.dart';
import 'package:agendamento_app/app/widgets/mercado_pago_connect_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class BarberProfileContent extends StatefulWidget {
  const BarberProfileContent({super.key});

  @override
  State<BarberProfileContent> createState() => _BarberProfileContentState();
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

class _BarberProfileContentState extends State<BarberProfileContent> {
  final AppFirestoreService _firestoreService = AppFirestoreService();
  final BarbershopLogoService _logoService = BarbershopLogoService();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _sobrenomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _ruaController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _locationLabelController =
      TextEditingController();

  final List<_ServiceFormItem> _serviceItems = [];
  final List<_PlanFormItem> _planItems = [];
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6];
  int _startHour = 9;
  int _endHour = 18;
  double? _locationLat;
  double? _locationLng;

  String? _currentImageUrl;
  String? _currentLogoData;
  File? _selectedImage;
  bool _loading = true;
  bool _savingBarbershop = false;
  String? _loadError;

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
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _telefoneController.dispose();
    _shopNameController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _cepController.dispose();
    _locationLabelController.dispose();
    for (final item in _serviceItems) {
      item.dispose();
    }
    for (final item in _planItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _loadError = 'Usuário não autenticado.';
      });
      return;
    }

    try {
      final profile = await _firestoreService.getUserProfile(user.uid);
      final shop = await _firestoreService.getBarbershopByOwner(user.uid);
      if (shop?.hasLegacyPixData == true) {
        await _firestoreService.removeLegacyPixData(user.uid);
      }

      if (!mounted) return;

      if (profile != null) {
        _nomeController.text = profile.nome;
        _sobrenomeController.text = profile.sobrenome;
        _telefoneController.text = profile.telefone;
      }

      if (shop != null) {
        _shopNameController.text = shop.nome;
        _bairroController.text = shop.endereco['bairro'] ?? '';
        _cidadeController.text = shop.endereco['cidade'] ?? '';
        _ruaController.text = shop.endereco['rua'] ?? '';
        _numeroController.text = shop.endereco['numero'] ?? '';
        _cepController.text = shop.endereco['cep'] ?? '';
        _currentImageUrl = shop.imageUrl;
        _currentLogoData = shop.logoData;
        _locationLat = shop.latitude;
        _locationLng = shop.longitude;
        _locationLabelController.text = shop.locationLabel ?? '';

        _serviceItems.clear();
        for (final service in shop.services) {
          _serviceItems.add(
            _ServiceFormItem(
              name: service.nome,
              price: service.preco.toStringAsFixed(2),
            ),
          );
        }
        if (_serviceItems.isEmpty) {
          _serviceItems.add(_ServiceFormItem());
        }

        _planItems.clear();
        for (final plan in shop.monthlyPlans) {
          _planItems.add(
            _PlanFormItem(
              name: plan.name,
              price: plan.price.toStringAsFixed(2),
              services: plan.services.join(', '),
            ),
          );
        }

        final days = shop.availability.keys
            .map((key) => int.tryParse(key))
            .whereType<int>()
            .toList();
        if (days.isNotEmpty) {
          _selectedDays = days;
          final firstDay = shop.availability[days.first.toString()] ?? [];
          final hourInts = firstDay.map((h) => int.tryParse(h) ?? 0).toList();
          if (hourInts.isNotEmpty) {
            hourInts.sort();
            _startHour = hourInts.first;
            _endHour = hourInts.last;
          }
        }
      } else {
        _serviceItems.add(_ServiceFormItem());
      }

      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Não foi possível carregar os dados da barbearia.';
      });
    }
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
      if (name.isEmpty || priceText.isEmpty) continue;
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

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestoreService.updateUserProfile(
      uid: user.uid,
      nome: _nomeController.text.trim(),
      sobrenome: _sobrenomeController.text.trim(),
      telefone: _telefoneController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil atualizado.')),
    );
  }

  Future<void> _saveBarbershop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _savingBarbershop) return;

    String? newLogoData;
    if (_selectedImage != null) {
      try {
        setState(() => _savingBarbershop = true);
        newLogoData = await _logoService.prepareLogo(_selectedImage!);
      } catch (e) {
        if (!mounted) return;
        setState(() => _savingBarbershop = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        return;
      }
    } else {
      setState(() => _savingBarbershop = true);
    }
    final endereco = {
      'bairro': _bairroController.text.trim(),
      'cidade': _cidadeController.text.trim(),
      'rua': _ruaController.text.trim(),
      'numero': _numeroController.text.trim(),
      'cep': _cepController.text.trim(),
    };

    final availability = buildAvailability(
      days: _selectedDays,
      startHour: _startHour,
      endHour: _endHour,
    );

    try {
      await _firestoreService.updateBarbershop(
        ownerId: user.uid,
        nome: _shopNameController.text.trim(),
        telefone: _telefoneController.text.trim(),
        endereco: endereco,
        location: (_locationLat != null && _locationLng != null)
            ? {
                'lat': _locationLat!,
                'lng': _locationLng!,
              }
            : null,
        locationLabel: _locationLabelController.text.trim(),
        logoData: newLogoData,
        services: _buildServices(),
        availability: availability,
        monthlyPlans: _buildMonthlyPlans(),
      );

      if (!mounted) return;
      setState(() {
        if (newLogoData != null) _currentLogoData = newLogoData;
        _selectedImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barbearia atualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _savingBarbershop = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _loadData();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const MercadoPagoConnectCard(),
          const SizedBox(height: 18),
          const Text(
            'Dados pessoais',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 3),
          const SizedBox(height: 8),
          TextField(
            controller: _nomeController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: _sobrenomeController,
            decoration: const InputDecoration(labelText: 'Sobrenome'),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: _telefoneController,
            decoration: const InputDecoration(labelText: 'Telefone'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Salvar perfil'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Barbearia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shopNameController,
            decoration: const InputDecoration(labelText: 'Nome da barbearia'),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: _bairroController,
            decoration: const InputDecoration(labelText: 'Bairro'),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: _cidadeController,
            decoration: const InputDecoration(labelText: 'Cidade'),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: _ruaController,
            decoration: const InputDecoration(labelText: 'Rua'),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numeroController,
                  decoration: const InputDecoration(labelText: 'Número'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cepController,
                  decoration: const InputDecoration(labelText: 'CEP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              if (!MapUtils.hasValidAddress(_currentEnderecoMap())) {
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
                final address = MapUtils.buildAddress(_currentEnderecoMap());
                _setGeocoding(true);
                final geocoded = await MapUtils.geocodeAddress(address);
                _setGeocoding(false);
                if (!context.mounted) return;
                if (geocoded == null) {
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
              if (!context.mounted) return;
              final result = await Navigator.push<LatLng>(
                context,
                MaterialPageRoute(
                  builder: (context) => MapPickerPage(initialPosition: initial),
                ),
              );
              if (!mounted) return;
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
          TextField(
            controller: _locationLabelController,
            decoration: const InputDecoration(
                labelText: 'Referência do local (opcional)'),
          ),
          if (_locationLat != null && _locationLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                'Local selecionado: '
                '${_locationLat!.toStringAsFixed(6)}, '
                '${_locationLng!.toStringAsFixed(6)}',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Text(
            'Logo da barbearia',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Ela aparecerá para os clientes. Se nenhuma logo for escolhida, '
            'a imagem padrão continuará sendo usada.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.cover)
                  : BarbershopImage(
                      logoData: _currentLogoData,
                      imageUrl: _currentImageUrl,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _savingBarbershop ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(
              _selectedImage == null
                  ? 'Escolher ou trocar logo'
                  : 'Trocar logo selecionada',
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
          const SizedBox(height: 12),
          Text(
            'Horários de funcionamento',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Wrap(
            spacing: 8,
            children: List.generate(7, (index) {
              final day = index + 1;
              final label =
                  ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][index];
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(
                  label,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                selected: isSelected,
                selectedColor: colorScheme.primary.withValues(alpha: 0.18),
                checkmarkColor: colorScheme.primary,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _startHour,
                  decoration: const InputDecoration(labelText: 'Início'),
                  items: List.generate(24, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text('${index.toString().padLeft(2, '0')}:00'),
                    );
                  }),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _startHour = value;
                      if (_endHour < _startHour) {
                        _endHour = _startHour;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _endHour,
                  decoration: const InputDecoration(labelText: 'Fim'),
                  items: List.generate(24, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text('${index.toString().padLeft(2, '0')}:00'),
                    );
                  }),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _endHour = value;
                      if (_endHour < _startHour) {
                        _startHour = _endHour;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _savingBarbershop ? null : _saveBarbershop,
            child: Text(
              _savingBarbershop ? 'Salvando...' : 'Salvar barbearia',
            ),
          ),
          const SizedBox(height: 20),
          const LegalLinksCard(),
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
              child: TextField(
                controller: item.nameController,
                decoration: const InputDecoration(labelText: 'Serviço'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: item.priceController,
                decoration: const InputDecoration(labelText: 'Preço'),
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

  void _setGeocoding(bool value) {
    if (!mounted) return;
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
            TextField(
              controller: item.nameController,
              decoration: const InputDecoration(labelText: 'Nome do plano'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: item.priceController,
              decoration: const InputDecoration(labelText: 'Valor do plano'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: item.servicesController,
              decoration: const InputDecoration(
                labelText: 'Serviços do plano (separados por vírgula)',
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
}
