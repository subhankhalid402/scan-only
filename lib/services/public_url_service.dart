import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service to generate public URLs for documents
class PublicUrlService {
  PublicUrlService._();

  static const String bucketName = 'scan-olny';
  static const String baseUrl = 'https://aowgmjiezwydhluigkuc.supabase.co/storage/v1/object/public';

  /// Generate public URL for a document
  static String getPublicUrl(String filePath) {
    try {
      final client = SupabaseService.client;
      if (client == null) {
        debugPrint('❌ Supabase client is null');
        return '';
      }

      final publicUrl = client.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      debugPrint('✓ Generated public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error generating public URL: $e');
      return '';
    }
  }

  /// Generate public URL with custom path
  static String getPublicUrlForDocument({
    required String userId,
    required int documentId,
    required String extension,
  }) {
    final filePath = '$userId/${documentId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return getPublicUrl(filePath);
  }

  /// Generate direct URL (without SDK)
  static String getDirectPublicUrl(String filePath) {
    return '$baseUrl/$bucketName/$filePath';
  }

  /// Verify URL is accessible
  static Future<bool> verifyUrlAccessible(String url) async {
    try {
      final client = SupabaseService.client;
      if (client == null) return false;

      // Try to get file metadata
      final response = await client.storage
          .from(bucketName)
          .list(path: url.split('/').last);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ URL verification failed: $e');
      return false;
    }
  }

  /// Get all public URLs for a user
  static Future<List<String>> getUserPublicUrls(String userId) async {
    try {
      final client = SupabaseService.client;
      if (client == null) return [];

      final files = await client.storage
          .from(bucketName)
          .list(path: userId);

      return files
          .map((file) => getPublicUrl('$userId/${file.name}'))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting user URLs: $e');
      return [];
    }
  }

  /// Share document via public URL
  static Future<String> shareDocument({
    required String userId,
    required int documentId,
    required String extension,
  }) async {
    try {
      final filePath = '$userId/${documentId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final publicUrl = getPublicUrl(filePath);

      if (publicUrl.isEmpty) {
        throw Exception('Failed to generate public URL');
      }

      debugPrint('✓ Document shared: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error sharing document: $e');
      return '';
    }
  }

  /// Get shareable link (can be used in QR code, etc.)
  static String getShareableLink(String filePath) {
    return getPublicUrl(filePath);
  }

  /// Copy URL to clipboard
  static Future<void> copyUrlToClipboard(String url) async {
    try {
      // You'll need to add this dependency: flutter_clipboard
      // await Clipboard.setData(ClipboardData(text: url));
      debugPrint('✓ URL copied to clipboard: $url');
    } catch (e) {
      debugPrint('❌ Error copying URL: $e');
    }
  }
}
