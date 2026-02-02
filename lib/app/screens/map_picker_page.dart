import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerPage extends StatefulWidget {
  final LatLng initialPosition;

  const MapPickerPage({
    super.key,
    required this.initialPosition,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar local no mapa'),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _selectedPosition,
          initialZoom: 15,
          onTap: (_, latLng) {
            setState(() {
              _selectedPosition = latLng;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ramos.kennedy.barberapp',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _selectedPosition,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, _selectedPosition);
        },
        label: const Text('Confirmar local'),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
