import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';

class SupabaseStorageService {
  static const String bucketName = 'barbershop-images';
  static const int maxUploadBytes = 2 * 1024 * 1024;
  static const int fullMaxWidth = 1280;
  static const int thumbMaxWidth = 320;
  static const int fullQuality = 75;
  static const int thumbQuality = 55;

  SupabaseClient _client() {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase não configurado.');
    }
    return Supabase.instance.client;
  }

  Future<BarbershopImageUploadResult> uploadBarbershopImage({
    required String userId,
    required File file,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final suffix = const Uuid().v4().replaceAll('-', '');
    final fullTarget = path.join(tempDir.path, 'barbershop_$suffix.jpg');
    final thumbTarget = path.join(tempDir.path, 'barbershop_${suffix}_thumb.jpg');

    final fullFile = await _compressImage(
      source: file,
      targetPath: fullTarget,
      maxWidth: fullMaxWidth,
      quality: fullQuality,
    );
    final thumbFile = await _compressImage(
      source: file,
      targetPath: thumbTarget,
      maxWidth: thumbMaxWidth,
      quality: thumbQuality,
    );

    if (fullFile == null || thumbFile == null) {
      throw Exception('Falha ao comprimir imagem.');
    }

    if (await fullFile.length() > maxUploadBytes) {
      throw Exception('Imagem acima do limite de 2MB após compressão.');
    }

    final client = _client();
    final baseKey = 'barbershops/$userId/$suffix';
    final fullObjectKey = '$baseKey.jpg';
    final thumbObjectKey = '${baseKey}_thumb.jpg';

    await client.storage.from(bucketName).upload(
          fullObjectKey,
          fullFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );

    await client.storage.from(bucketName).upload(
          thumbObjectKey,
          thumbFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );

    final imageUrl =
        client.storage.from(bucketName).getPublicUrl(fullObjectKey);
    final thumbUrl =
        client.storage.from(bucketName).getPublicUrl(thumbObjectKey);

    return BarbershopImageUploadResult(
      imageUrl: imageUrl,
      thumbUrl: thumbUrl,
    );
  }

  Future<File?> _compressImage({
    required File source,
    required String targetPath,
    required int maxWidth,
    required int quality,
  }) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      format: CompressFormat.jpeg,
    );
    if (result == null) return null;
    return File(result.path);
  }
}

class BarbershopImageUploadResult {
  final String imageUrl;
  final String thumbUrl;

  BarbershopImageUploadResult({
    required this.imageUrl,
    required this.thumbUrl,
  });
}
