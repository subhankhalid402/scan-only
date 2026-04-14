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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text(
          'Office Export Tools',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _tile(
            context,
            icon: Iconsax.receipt,
            title: 'Invoice Export',
            subtitle: 'PDF, Excel, Word, PPT, Slides',
            color: AppColors.gold,
            onTap: () => _go(context, const InvoiceTemplateBuilderScreen()),
          ),
          _tile(
            context,
            icon: Iconsax.document_text,
            title: 'Contract Export',
            subtitle: 'PDF + Office formats',
            color: AppColors.navyMid,
            onTap: () => _go(
              context,
              const DocumentTemplateBuilderScreen(templateName: 'Contract'),
            ),
          ),
          _tile(
            context,
            icon: Iconsax.card,
            title: 'Business Card Export',
            subtitle: 'PDF + Office formats',
            color: AppColors.purple,
            onTap: () => _go(
              context,
              const DocumentTemplateBuilderScreen(
                  templateName: 'Business Card'),
            ),
          ),
          _tile(
            context,
            icon: Iconsax.receipt,
            title: 'Receipt Export',
            subtitle: 'PDF + Office formats',
            color: AppColors.green,
            onTap: () => _go(
              context,
              const DocumentTemplateBuilderScreen(templateName: 'Receipt'),
            ),
          ),
          _tile(
            context,
            icon: Iconsax.text_block,
            title: 'Whiteboard Notes Export',
            subtitle: 'PDF + Office formats',
            color: AppColors.blue,
            onTap: () => _go(
              context,
              const DocumentTemplateBuilderScreen(
                templateName: 'Whiteboard Notes',
              ),
            ),
          ),
          _tile(
            context,
            icon: Iconsax.element_3,
            title: 'Table Sheet Export',
            subtitle: 'PDF + Office formats',
            color: AppColors.orange,
            onTap: () => _go(
              context,
              const DocumentTemplateBuilderScreen(templateName: 'Table Sheet'),
            ),
          ),
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
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
