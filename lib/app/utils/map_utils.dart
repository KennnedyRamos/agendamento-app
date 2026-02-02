import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapUtils {
  static String buildAddress(Map<String, dynamic> endereco) {
    final rua = (endereco['rua'] ?? '').toString().trim();
    final numero = (endereco['numero'] ?? '').toString().trim();
    final bairro = (endereco['bairro'] ?? '').toString().trim();
    final cidade = (endereco['cidade'] ?? '').toString().trim();
    final cep = (endereco['cep'] ?? '').toString().trim();

    final parts = <String>[];
    if (rua.isNotEmpty) {
      parts.add(numero.isNotEmpty ? '$rua, $numero' : rua);
    }
    if (bairro.isNotEmpty) {
      parts.add(bairro);
    }
    if (cidade.isNotEmpty) {
      parts.add(cidade);
    }
    if (cep.isNotEmpty) {
      parts.add(cep);
    }
    return parts.join(' - ');
  }

  static bool hasValidAddress(Map<String, dynamic> endereco) {
    return buildAddress(endereco).trim().isNotEmpty;
  }

  static bool hasCoordinates(double? latitude, double? longitude) {
    return latitude != null && longitude != null;
  }

  static Future<LatLng?> geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(trimmed)}',
    );

    final client = HttpClient()..userAgent = 'agendamento_app/1.0';
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> openMapSearch({
    required Map<String, dynamic> endereco,
    String? name,
    double? latitude,
    double? longitude,
  }) async {
    final address = buildAddress(endereco);
    final query = _buildQuery(name, address, latitude, longitude);
    if (query.isEmpty) return false;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openDirections({
    required Map<String, dynamic> endereco,
    String? name,
    double? latitude,
    double? longitude,
  }) async {
    final address = buildAddress(endereco);
    final query = _buildQuery(name, address, latitude, longitude);
    if (query.isEmpty) return false;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(query)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _buildQuery(
    String? name,
    String address,
    double? latitude,
    double? longitude,
  ) {
    final safeName = (name ?? '').trim();
    if (latitude != null && longitude != null) {
      return '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    }
    if (safeName.isEmpty && address.isEmpty) return '';
    if (safeName.isEmpty) return address;
    if (address.isEmpty) return safeName;
    return '$safeName, $address';
  }
}
