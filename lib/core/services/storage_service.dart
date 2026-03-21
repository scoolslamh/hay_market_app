import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final supabase = Supabase.instance.client;

  /// رفع صورة منتج
  Future<String?> uploadProductImage({
    required File file,
    required String marketId,
  }) async {
    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      final path = "products/$marketId/$fileName";

      await supabase.storage
          .from('products')
          .upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = supabase.storage.from('products').getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }
}
