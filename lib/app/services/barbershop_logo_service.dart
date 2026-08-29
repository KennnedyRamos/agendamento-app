import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class BarbershopLogoService {
  // O logo permanece pequeno porque acompanha os documentos exibidos na
  // descoberta. Isso reduz tráfego, memória e tempo de renderização.
  static const int _maxLogoBytes = 64 * 1024;

  Future<String> prepareLogo(File file) async {
    Uint8List? bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 384,
      minHeight: 384,
      quality: 60,
      format: CompressFormat.jpeg,
    );

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Não foi possível processar a imagem escolhida.');
    }

    if (bytes.length > _maxLogoBytes) {
      bytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 256,
        minHeight: 256,
        quality: 40,
        format: CompressFormat.jpeg,
      );
    }

    if (bytes == null || bytes.isEmpty || bytes.length > _maxLogoBytes) {
      throw Exception(
        'A imagem ficou muito grande. Escolha uma imagem mais simples.',
      );
    }

    return base64Encode(bytes);
  }
}
