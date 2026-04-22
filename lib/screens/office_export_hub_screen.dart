import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../theme.dart';
import 'document_template_builder_screen.dart';
import 'invoice_template_builder_screen.dart';

class OfficeExportHubScreen extends StatelessWidget {
  const OfficeExportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Office Export Tools',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _tile(context,
              icon: Iconsax.receipt,
              title: 'Invoice',
              subtitle: 'PDF, Excel, Word, PPT',
              color: AppColors.gold,
              onTap: () => _go(context, const InvoiceTemplateBuilderScreen())),
          _tile(context,
              icon: Iconsax.document_text,
              title: 'Contract',
              subtitle: 'PDF + Office formats',
              color: AppColors.navyMid,
              onTap: () => _go(context,
                  DocumentTemplateBuilderScreen(templateName: 'Contract'))),
          _tile(context,
              icon: Icons.workspace_premium_rounded,
              title: 'Certificate',
              subtitle: 'PDF + Office formats',
              color: const Color(0xFFD4AF37),
              onTap: () => _go(context,
                  DocumentTemplateBuilderScreen(templateName: 'Certificate'))),
          _tile(context,
              icon: Iconsax.card,
              title: 'Business Card',
              subtitle: 'PDF + Office formats',
              color: AppColors.purple,
              onTap: () => _go(
                  context,
                  DocumentTemplateBuilderScreen(
                      templateName: 'Business Card'))),
          _tile(context,
              icon: Iconsax.receipt_2,
              title: 'Receipt',
              subtitle: 'PDF + Office formats',
              color: AppColors.green,
              onTap: () => _go(context,
                  DocumentTemplateBuilderScreen(templateName: 'Receipt'))),
          _tile(context,
              icon: Iconsax.text_block,
              title: 'Whiteboard Notes',
              subtitle: 'PDF + Office formats',
              color: AppColors.blue,
              onTap: () => _go(
                  context,
                  DocumentTemplateBuilderScreen(
                      templateName: 'Whiteboard Notes'))),
          _tile(context,
              icon: Iconsax.element_3,
              title: 'Table Sheet',
              subtitle: 'PDF + Office formats',
              color: AppColors.orange,
              onTap: () => _go(context,
                  DocumentTemplateBuilderScreen(templateName: 'Table Sheet'))),
          _tile(context,
              icon: Iconsax.note_text,
              title: 'Meeting Notes',
              subtitle: 'PDF + Office formats',
              color: AppColors.navyMid,
              onTap: () => _go(context,
                  DocumentTemplateBuilderScreen(templateName: 'Meeting Notes'))),
          _tile(context,
              icon: Iconsax.personalcard,
              title: 'Resume / CV',
              subtitle: 'PDF + Office formats',
              color: AppColors.purple,
              onTap: () => _go(context,
                  DocumentTemplateBuilderScreen(templateName: 'Resume / CV'))),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyDark)),
                  Text(subtitle,
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
