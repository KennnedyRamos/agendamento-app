import 'dart:convert';

import 'package:flutter/material.dart';

class BarbershopImage extends StatelessWidget {
  static const String defaultAsset = 'assets/images/barber_home_hero.png';

  final String? logoData;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String fallbackAsset;

  const BarbershopImage({
    super.key,
    this.logoData,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallbackAsset = defaultAsset,
  });

  Widget _fallback() {
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => _defaultImage(),
      );
    }
    return _defaultImage();
  }

  Widget _defaultImage() {
    return Image.asset(
      fallbackAsset,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final encoded = logoData?.trim() ?? '';
    if (encoded.isEmpty) return _fallback();

    try {
      final payload = encoded.contains(',') ? encoded.split(',').last : encoded;
      final bytes = base64Decode(payload);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } on FormatException {
      return _fallback();
    }
  }
}
