import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import 'document_template_builder_screen.dart';
import 'invoice_template_builder_screen.dart';
import 'scan_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  static const _templates = <_TemplateItem>[
    _TemplateItem(
      name: 'Invoice',
      icon: Iconsax.receipt,
      color: AppColors.gold,
      description: 'Professional invoice with items, totals & export',
      scanType: 'document',
      route: _TemplateRoute.invoice,
    ),
    _TemplateItem(
      name: 'Contract',
      icon: Iconsax.document_text,
      color: AppColors.navyMid,
      description: 'Legal agreement with parties, terms & signature',
      scanType: 'document',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Certificate',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFD4AF37),
      description: 'Award or achievement certificate with seal',
      scanType: 'document',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Business Card',
      icon: Iconsax.card,
      color: AppColors.navyMid,
      description: 'Card ratio + sharp ID-style enhance',
      scanType: 'id_card',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Receipt',
      icon: Iconsax.receipt_2,
      color: AppColors.green,
      description: 'Thermal paper + amount extraction flow',
      scanType: 'receipt',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Whiteboard Notes',
      icon: Iconsax.text_block,
      color: AppColors.blue,
      description: 'Glare cleanup + perspective correction',
      scanType: 'whiteboard',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Table Sheet',
      icon: Iconsax.element_3,
      color: AppColors.gold,
      description: 'Table mode with CSV-friendly output',
      scanType: 'table',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Meeting Notes',
      icon: Iconsax.note_text,
      color: AppColors.navyMid,
      description: 'Agenda, action items & attendees',
      scanType: 'document',
      route: _TemplateRoute.builder,
    ),
    _TemplateItem(
      name: 'Resume / CV',
      icon: Iconsax.personalcard,
      color: AppColors.purple,
      description: 'Professional resume with sections',
      scanType: 'document',
      route: _TemplateRoute.builder,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // ── Responsive layout: screen width se columns decide karo ──
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 360 ? 1 : 2; // chhoti screen pe 1 column

    // ── Safe area + keyboard ke liye padding ──
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'Document Templates',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          14,
          14,
          14,
          14 + bottomPadding, // bottom nav bar ke liye extra padding
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // ── FIX: aspect ratio increase kiya taake card cut na ho ──
          // Pehle 0.72 tha, ab 0.78 hai — description text ke liye space
          childAspectRatio: 0.78,
        ),
        itemCount: _templates.length,
        itemBuilder: (_, i) => _TemplateCard(
          template: _templates[i],
          onTap: () => _useTemplate(context, _templates[i]),
        ),
      ),
    );
  }

  void _useTemplate(BuildContext context, _TemplateItem t) {
    switch (t.route) {
      case _TemplateRoute.invoice:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InvoiceTemplateBuilderScreen(),
          ),
        );
        break;
      case _TemplateRoute.builder:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentTemplateBuilderScreen(
              templateName: t.name,
              scanType: t.scanType,
            ),
          ),
        );
        break;
      // ── FIX: scan route bhi implement kiya (pehle dead code tha) ──
      case _TemplateRoute.scan:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ScanScreen(scanType: t.scanType, templateLabel: t.name),
          ),
        );
        break;
    }
  }
}

enum _TemplateRoute { invoice, builder, scan }

class _TemplateItem {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String scanType;
  final _TemplateRoute route;

  const _TemplateItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.scanType,
    required this.route,
  });
}

class _TemplateCard extends StatelessWidget {
  final _TemplateItem template;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: template.color.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // ── FIX: Column ko IntrinsicHeight ke baghair handle karo ──
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area — fixed height
            Container(
              height: 88,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: template.color.withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _TemplateThumbnail(template: template),
            ),

            // Template name
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Row(
                children: [
                  Icon(template.icon, size: 15, color: template.color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      template.name,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Description — maxLines:2 overflow safe
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                template.description,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── FIX: Spacer ki jagah Expanded use karo taake overflow na ho ──
            const Expanded(child: SizedBox()),

            // Use Template button
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Container(
                width: double.infinity, // full width button — better tap target
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: template.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Use Template',
                  textAlign: TextAlign.center,
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
  }
}

class _TemplateThumbnail extends StatelessWidget {
  final _TemplateItem template;
  const _TemplateThumbnail({required this.template});

  Widget _line({double w = double.infinity, double h = 7, double op = 0.1}) =>
      Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(op),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    switch (template.name) {
      case 'Invoice':
        return _invoiceThumb();
      case 'Contract':
        return _contractThumb();
      case 'Certificate':
        return _certificateThumb();
      case 'Business Card':
        return _businessCardThumb();
      case 'Receipt':
        return _receiptThumb();
      case 'Whiteboard Notes':
        return _whiteboardThumb();
      case 'Resume / CV':
        return _resumeThumb();
      case 'Meeting Notes':
        return _meetingThumb();
      // ── FIX: 'Table Sheet' explicitly add kiya — pehle default mein tha ──
      case 'Table Sheet':
        return _tableThumb();
      default:
        return _tableThumb();
    }
  }

  Widget _invoiceThumb() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _line(w: 70, h: 10, op: 0.16),
            const Spacer(),
            _line(w: 38, h: 10, op: 0.16)
          ]),
          const SizedBox(height: 8),
          _line(),
          const SizedBox(height: 4),
          _line(w: 90),
          const Spacer(),
          Row(
              children: [_line(w: 64), const Spacer(), _line(w: 46, op: 0.2)]),
        ],
      );

  Widget _contractThumb() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(w: 88, h: 11, op: 0.16),
          const SizedBox(height: 7),
          _line(),
          const SizedBox(height: 4),
          _line(),
          const SizedBox(height: 4),
          _line(w: 110),
          const Spacer(),
          _line(w: 74, h: 9, op: 0.2),
        ],
      );

  Widget _certificateThumb() => Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: const Color(0xFFD4AF37).withOpacity(0.7), size: 26),
              const SizedBox(height: 4),
              _line(w: 80, h: 7, op: 0.18),
              const SizedBox(height: 4),
              _line(w: 60, h: 5, op: 0.12),
            ],
          ),
        ),
      );

  Widget _businessCardThumb() => Center(
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [template.color, template.color.withOpacity(0.68)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(w: 70, h: 8, op: 0.38),
                const SizedBox(height: 5),
                _line(w: 46, h: 6, op: 0.34),
                const Spacer(),
                _line(w: 84, h: 6, op: 0.34),
              ],
            ),
          ),
        ),
      );

  Widget _receiptThumb() => Center(
        child: Container(
          width: 72,
          height: 82,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(children: [
              _line(h: 6),
              const SizedBox(height: 4),
              _line(h: 6),
              const SizedBox(height: 7),
              _line(h: 6),
              const SizedBox(height: 4),
              _line(h: 6),
              const Spacer(),
              _line(h: 8, op: 0.2),
            ]),
          ),
        ),
      );

  Widget _whiteboardThumb() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _line(w: 22, h: 22, op: 0.08),
                const SizedBox(width: 8),
                _line(w: 70, h: 9)
              ]),
              const SizedBox(height: 8),
              _line(),
              const SizedBox(height: 4),
              _line(w: 94),
            ],
          ),
        ),
      );

  Widget _resumeThumb() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line(w: 60, h: 7, op: 0.2),
              const SizedBox(height: 3),
              _line(w: 40, h: 5, op: 0.12),
            ]),
          ]),
          const SizedBox(height: 8),
          _line(w: 50, h: 6, op: 0.18),
          const SizedBox(height: 4),
          _line(),
          const SizedBox(height: 3),
          _line(w: 80),
        ],
      );

  Widget _meetingThumb() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(w: 88, h: 9, op: 0.18),
          const SizedBox(height: 6),
          Row(children: [
            _line(w: 8, h: 8, op: 0.3),
            const SizedBox(width: 6),
            _line(w: 80, h: 7)
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _line(w: 8, h: 8, op: 0.3),
            const SizedBox(width: 6),
            _line(w: 70, h: 7)
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _line(w: 8, h: 8, op: 0.3),
            const SizedBox(width: 6),
            _line(w: 60, h: 7)
          ]),
        ],
      );

  Widget _tableThumb() => Container(
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
                            ? template.color.withOpacity(0.18)
                            : Colors.black.withOpacity(0.06),
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