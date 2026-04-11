import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = [
      {
        'name': 'Invoice',
        'icon': Iconsax.receipt,
        'color': AppColors.gold,
        'description': 'Professional invoice template'
      },
      {
        'name': 'Contract',
        'icon': Iconsax.document_text,
        'color': AppColors.navyMid,
        'description': 'Legal contract template'
      },
      {
        'name': 'Business Card',
        'icon': Iconsax.card,
        'color': AppColors.blue,
        'description': 'Business card template'
      },
      {
        'name': 'Receipt',
        'icon': Iconsax.receipt,
        'color': AppColors.green,
        'description': 'Receipt template'
      },
      {
        'name': 'Certificate',
        'icon': Iconsax.award,
        'color': AppColors.purple,
        'description': 'Certificate template'
      },
      {
        'name': 'Form',
        'icon': Iconsax.document,
        'color': AppColors.red,
        'description': 'Form template'
      },
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
            onTap: () => _useTemplate(context, template['name'] as String),
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
                    template['icon'] as IconData,
                    size: 48,
                    color: template['color'] as Color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    template['name'] as String,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template['description'] as String,
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

  void _useTemplate(BuildContext context, String templateName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Using $templateName template'),
        backgroundColor: AppColors.gold,
      ),
    );
    Navigator.pop(context, templateName);
  }
}
