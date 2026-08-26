import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class BarbershopLogoService {
  static const int _maxLogoBytes = 180 * 1024;

  Future<String> prepareLogo(File file) async {
    Uint8List? bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 512,
      minHeight: 512,
      quality: 72,
      format: CompressFormat.jpeg,
    );

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Não foi possível processar a imagem escolhida.');
    }

    if (bytes.length > _maxLogoBytes) {
      bytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 384,
        minHeight: 384,
        quality: 45,
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
