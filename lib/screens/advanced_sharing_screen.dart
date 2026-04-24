import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/email_service.dart';
import '../services/share_file_service.dart';

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

  Future<void> _shareViaApp() async {
    try {
      final f = File(widget.filePath);
      if (!await f.exists()) {
        if (!mounted) return;
        _showError('File not found. It may have been moved or deleted.');
        return;
      }
      // Do not pass `text`: many apps (e.g. WhatsApp) then send only the caption
      // and omit the file attachment. File name comes from the path / XFile.name.
      await ShareFileService.sharePaths([widget.filePath]);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not share: $e');
    }
  }

  String _formatFileSizeLine() {
    try {
      final f = File(widget.filePath);
      if (!f.existsSync()) return 'Size: —';
      final mb = f.lengthSync() / (1024 * 1024);
      return 'Size: ${mb.toStringAsFixed(2)} MB';
    } catch (_) {
      return 'Size: —';
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) return false;

    // Block common dummy/disposable domains
    const blockedDomains = [
      'test.com', 'example.com', 'dummy.com', 'fake.com',
      'abc.com', 'xyz.com', 'aaa.com', 'bbb.com', 'ccc.com',
      'mailinator.com', 'guerrillamail.com', 'tempmail.com',
      'throwaway.email', 'yopmail.com', 'sharklasers.com',
      'trashmail.com', 'dispostable.com', 'maildrop.cc',
    ];

    final domain = email.split('@').last.toLowerCase();
    if (blockedDomains.contains(domain)) return false;

    // Block obviously fake local parts
    final localPart = email.split('@').first.toLowerCase();
    const blockedLocalParts = ['test', 'dummy', 'fake', 'asdf', 'qwerty', 'aaaa', 'bbbb'];
    if (blockedLocalParts.contains(localPart)) return false;

    return true;
  }

  void _shareViaEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter email address');
      return;
    }
    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _isSharing = true);
    try {
      final success = await EmailService.instance.sendDocumentEmail(
        recipientEmail: email,
        filePath: widget.filePath,
        fileName: widget.fileName,
      );

      if (!mounted) return;
      if (success) {
        _showSuccess('Email sent successfully');
        Navigator.pop(context);
      } else {
        _showError('Failed to send email');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _shareViaLink() async {
    try {
      final f = File(widget.filePath);
      if (!await f.exists()) {
        if (!mounted) return;
        _showError('File not found. It may have been moved or deleted.');
        return;
      }
      final uri = Uri.file(widget.filePath).toString();
      await Clipboard.setData(ClipboardData(text: uri));
      await Share.share(
        'Local file path (same device only):\n$uri',
        subject: widget.fileName,
      );
      if (!mounted) return;
      _showSuccess('Path copied; share sheet opened with text only.');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not share link: $e');
    }
  }

  Future<void> _shareViaQR() async {
    final payload = Uri.file(widget.filePath).toString();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QR Share Data',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.navyDark,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                payload,
                style: GoogleFonts.nunito(fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: payload));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('QR data copied.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                      icon: const Icon(Icons.copy, color: AppColors.navyDark),
                      label: Text(
                        'Copy',
                        style: GoogleFonts.nunito(
                          color: AppColors.navyDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Share.share('QR data:\n$payload');
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Iconsax.share),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                    'Share file',
                    () {
                      _shareViaApp();
                    },
                    AppColors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shareOption(
                    Iconsax.link,
                    'Path as text',
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
                  Text(_formatFileSizeLine(), style: GoogleFonts.nunito(fontSize: 12)),
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
