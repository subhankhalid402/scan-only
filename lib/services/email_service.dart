import 'dart:io';
import 'package:share_plus/share_plus.dart';

/// Email service - uses device's native share sheet to send documents via email.
/// This is the correct approach for mobile apps (no SMTP credentials needed).
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();
  static EmailService get instance => _instance;

  /// Sends a document via the device's native share sheet (email client, WhatsApp, etc.)
  Future<bool> sendDocumentEmail({
    required String recipientEmail,
    required String filePath,
    required String fileName,
    String? subject,
    String? body,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      final emailSubject = subject ?? 'Document: $fileName';
      final emailBody = body ?? 'Please find the attached document: $fileName';

      // Use native share sheet - user picks their email app
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: emailSubject,
        text: 'To: $recipientEmail\n\n$emailBody',
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      return false;
    }
  }

  /// Share document via link using native share sheet
  Future<bool> sendDocumentViaLink({
    required String filePath,
    required String fileName,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: fileName,
        text: 'Sharing document: $fileName',
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      return false;
    }
  }
}
