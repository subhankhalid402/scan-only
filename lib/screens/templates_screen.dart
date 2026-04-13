import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import 'scan_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = <_TemplateItem>[
      const _TemplateItem(
        name: 'Invoice',
        icon: Iconsax.receipt,
        color: AppColors.gold,
        description: 'Invoice layout with amount fields',
        scanType: 'document',
      ),
      const _TemplateItem(
        name: 'Contract',
        icon: Iconsax.document_text,
        color: AppColors.navyMid,
        description: 'A4 legal pages, clean text profile',
        scanType: 'document',
      ),
      const _TemplateItem(
        name: 'Business Card',
        icon: Iconsax.card,
        color: AppColors.navyMid,
        description: 'Card ratio + sharp ID-style enhance',
        scanType: 'id_card',
      ),
      const _TemplateItem(
        name: 'Receipt',
        icon: Iconsax.receipt,
        color: AppColors.gold,
        description: 'Thermal paper + amount extraction flow',
        scanType: 'receipt',
      ),
      const _TemplateItem(
        name: 'Whiteboard Notes',
        icon: Iconsax.text_block,
        color: AppColors.navyMid,
        description: 'Glare cleanup + perspective correction',
        scanType: 'whiteboard',
      ),
      const _TemplateItem(
        name: 'Table Sheet',
        icon: Iconsax.element_3,
        color: AppColors.gold,
        description: 'Table mode with CSV-friendly output',
        scanType: 'table',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Document Templates', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: templates.length,
        itemBuilder: (_, i) {
          final template = templates[i];
          return GestureDetector(
            onTap: () => _useTemplate(context, template),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    template.icon,
                    size: 48,
                    color: template.color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    template.name,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _useTemplate(BuildContext context, _TemplateItem template) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          scanType: template.scanType,
          templateLabel: template.name,
        ),
      ),
    );
  }
}

class _TemplateItem {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String scanType;

  const _TemplateItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.scanType,
  });
}
