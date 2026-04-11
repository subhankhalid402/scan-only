import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/email_service.dart';

class AdvancedSharingScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const AdvancedSharingScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AdvancedSharingScreen> createState() => _AdvancedSharingScreenState();
}

class _AdvancedSharingScreenState extends State<AdvancedSharingScreen> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSharing = false;

  void _shareViaApp() async {
    await Share.shareXFiles(
      [XFile(widget.filePath)],
      text: 'Check out this document: ${widget.fileName}',
    );
  }

  void _shareViaEmail() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter email address');
      return;
    }

    setState(() => _isSharing = true);
    try {
      final success = await EmailService.instance.sendDocumentEmail(
        recipientEmail: _emailController.text,
        filePath: widget.filePath,
        fileName: widget.fileName,
      );

      if (success) {
        _showSuccess('Email sent successfully');
        Navigator.pop(context);
      } else {
        _showError('Failed to send email');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSharing = false);
    }
  }

  void _shareViaLink() {
    _showInfo('Link sharing feature coming soon');
  }

  void _shareViaQR() {
    _showInfo('QR code sharing feature coming soon');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.green),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Document', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick share options
            Text('Quick Share', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _shareOption(
                    Iconsax.share,
                    'Share App',
                    _shareViaApp,
                    AppColors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shareOption(
                    Iconsax.link,
                    'Share Link',
                    _shareViaLink,
                    AppColors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shareOption(
                    Iconsax.code,
                    'QR Code',
                    _shareViaQR,
                    AppColors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Email sharing
            Text('Share via Email', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Recipient email',
                prefixIcon: const Icon(Iconsax.sms),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Message (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSharing ? null : _shareViaEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSharing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Send Email',
                        style: GoogleFonts.nunito(
                          color: AppColors.navyDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // File info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('File Info', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Name: ${widget.fileName}', style: GoogleFonts.nunito(fontSize: 12)),
                  Text('Size: ${File(widget.filePath).lengthSync() / 1024 / 1024} MB', style: GoogleFonts.nunito(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
