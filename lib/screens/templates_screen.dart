import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import 'document_template_builder_screen.dart';
import 'invoice_template_builder_screen.dart';
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
        description: 'Real editable invoice template (Canva style)',
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
        title: Text('Document Templates',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
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
                border:
                    Border.all(color: template.color.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 92,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: template.color.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: _TemplateThumbnail(template: template),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Row(
                      children: [
                        Icon(template.icon, size: 17, color: template.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            template.name,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      template.description,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: template.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Use Template',
                        style: GoogleFonts.nunito(
                          color: template.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
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
    if (template.name == 'Invoice') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvoiceTemplateBuilderScreen()),
      );
      return;
    }
    const builderTemplates = {
      'Contract',
      'Business Card',
      'Receipt',
      'Whiteboard Notes',
      'Table Sheet',
    };
    if (builderTemplates.contains(template.name)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentTemplateBuilderScreen(
            templateName: template.name,
          ),
        ),
      );
      return;
    }
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

class _TemplateThumbnail extends StatelessWidget {
  final _TemplateItem template;
  const _TemplateThumbnail({required this.template});

  @override
  Widget build(BuildContext context) {
    switch (template.name) {
      case 'Invoice':
        return _invoiceThumb();
      case 'Contract':
        return _contractThumb();
      case 'Business Card':
        return _businessCardThumb();
      case 'Receipt':
        return _receiptThumb();
      case 'Whiteboard Notes':
        return _whiteboardThumb();
      default:
        return _tableThumb();
    }
  }

  Widget _line({double w = double.infinity, double h = 7, double a = 0.1}) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: a),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _invoiceThumb() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _line(w: 70, h: 10, a: 0.16),
          const Spacer(),
          _line(w: 38, h: 10, a: 0.16)
        ]),
        const SizedBox(height: 8),
        _line(),
        const SizedBox(height: 4),
        _line(w: 90),
        const Spacer(),
        Row(children: [_line(w: 64), const Spacer(), _line(w: 46, a: 0.2)]),
      ],
    );
  }

  Widget _contractThumb() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(w: 88, h: 11, a: 0.16),
        const SizedBox(height: 7),
        _line(),
        const SizedBox(height: 4),
        _line(),
        const SizedBox(height: 4),
        _line(w: 110),
        const Spacer(),
        _line(w: 74, h: 9, a: 0.2),
      ],
    );
  }

  Widget _businessCardThumb() {
    return Center(
      child: Container(
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [template.color, template.color.withValues(alpha: 0.68)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(w: 70, h: 8, a: 0.38),
              const SizedBox(height: 5),
              _line(w: 46, h: 6, a: 0.34),
              const Spacer(),
              _line(w: 84, h: 6, a: 0.34),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptThumb() {
    return Center(
      child: Container(
        width: 78,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            children: [
              _line(h: 6),
              const SizedBox(height: 4),
              _line(h: 6),
              const SizedBox(height: 7),
              _line(h: 6),
              const SizedBox(height: 4),
              _line(h: 6),
              const Spacer(),
              _line(h: 8, a: 0.2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteboardThumb() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _line(w: 22, h: 22, a: 0.08),
              const SizedBox(width: 8),
              _line(w: 86, h: 9)
            ]),
            const SizedBox(height: 8),
            _line(),
            const SizedBox(height: 4),
            _line(w: 94),
            const SizedBox(height: 6),
            Row(children: [
              _line(w: 40, a: 0.18),
              const SizedBox(width: 8),
              _line(w: 40, a: 0.18)
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tableThumb() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: List.generate(4, (r) {
          return Expanded(
            child: Row(
              children: List.generate(3, (c) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: (r == 0 || c == 0)
                          ? template.color.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
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
