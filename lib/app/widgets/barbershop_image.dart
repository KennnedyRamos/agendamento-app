import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class BarbershopImage extends StatefulWidget {
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

  @override
  State<BarbershopImage> createState() => _BarbershopImageState();
}

class _BarbershopImageState extends State<BarbershopImage> {
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _decodeLogo();
  }

  @override
  void didUpdateWidget(covariant BarbershopImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoData != widget.logoData) _decodeLogo();
  }

  void _decodeLogo() {
    final encoded = widget.logoData?.trim() ?? '';
    if (encoded.isEmpty) {
      _logoBytes = null;
      return;
    }
    try {
      final payload = encoded.contains(',') ? encoded.split(',').last : encoded;
      _logoBytes = base64Decode(payload);
    } on FormatException {
      _logoBytes = null;
    }
  }

  Widget _fallback() {
    final url = widget.imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        errorBuilder: (_, __, ___) => _defaultImage(),
      );
    }
    return _defaultImage();
  }

  Widget _defaultImage() {
    return Image.asset(
      widget.fallbackAsset,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _logoBytes;
    if (bytes == null) return _fallback();
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = widget.width == null
        ? null
        : (widget.width! * pixelRatio).round().clamp(1, 2048);
    return Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }
}
