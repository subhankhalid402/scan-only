import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import 'document_template_builder_screen.dart';
import 'invoice_template_builder_screen.dart';

// ─────────────────────────────────────────────
//  Data layer
// ─────────────────────────────────────────────

enum _TemplateRoute { invoice, builder }

enum _TemplateCategory { business, legal, personal, scan }

class _TemplateItem {
  final String name;
  final IconData icon;
  final Color color;
  final Color colorDark;
  final String description;
  final String badge;
  final String badgeIcon;
  final String scanType;
  final _TemplateRoute route;
  final _TemplateCategory category;

  const _TemplateItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.colorDark,
    required this.description,
    required this.badge,
    required this.badgeIcon,
    required this.scanType,
    required this.route,
    required this.category,
  });
}

const _templates = <_TemplateItem>[
  // ── Business ──
  _TemplateItem(
    name: 'Invoice',
    icon: Iconsax.receipt,
    color: Color(0xFFFFF8E1),
    colorDark: Color(0xFFE6A817),
    description: 'Professional invoice with line items, totals & multi-format export',
    badge: 'PDF · Excel · Word',
    badgeIcon: '📄',
    scanType: 'document',
    route: _TemplateRoute.invoice,
    category: _TemplateCategory.business,
  ),
  _TemplateItem(
    name: 'Business Card',
    icon: Iconsax.card,
    color: Color(0xFFE8EAF6),
    colorDark: Color(0xFF162460),
    description: 'Professional identity card with contact details & company branding',
    badge: 'Print Ready',
    badgeIcon: '🪪',
    scanType: 'id_card',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.business,
  ),
  _TemplateItem(
    name: 'Receipt',
    icon: Iconsax.receipt_2,
    color: Color(0xFFE8F5E9),
    colorDark: Color(0xFF2E7D32),
    description: 'Itemized payment receipt with tax summary & cashier signature',
    badge: 'OCR · Export',
    badgeIcon: '🧾',
    scanType: 'receipt',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.business,
  ),
  // ── Legal ──
  _TemplateItem(
    name: 'Contract',
    icon: Iconsax.document_text,
    color: Color(0xFFE3F2FD),
    colorDark: Color(0xFF0B1740),
    description: 'Legal agreement with parties, terms, clauses & dual signature blocks',
    badge: 'Legal · Signature',
    badgeIcon: '⚖️',
    scanType: 'document',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.legal,
  ),
  _TemplateItem(
    name: 'Certificate',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFFF9E6),
    colorDark: Color(0xFFD4AF37),
    description: 'Award or achievement certificate with gold seal & formal layout',
    badge: 'Print Ready',
    badgeIcon: '🏆',
    scanType: 'document',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.legal,
  ),
  // ── Personal ──
  _TemplateItem(
    name: 'Resume / CV',
    icon: Iconsax.personalcard,
    color: Color(0xFFF3E5F5),
    colorDark: Color(0xFF6A1B9A),
    description: 'Professional CV with objective, experience, education & skills',
    badge: 'PDF Export',
    badgeIcon: '👤',
    scanType: 'document',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.personal,
  ),
  _TemplateItem(
    name: 'Meeting Notes',
    icon: Iconsax.note_text,
    color: Color(0xFFE3F2FD),
    colorDark: Color(0xFF1565C0),
    description: 'Agenda, action items, attendees & facilitator sign-off',
    badge: 'Share · Export',
    badgeIcon: '📋',
    scanType: 'document',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.personal,
  ),
  // ── Scan Modes ──
  _TemplateItem(
    name: 'Whiteboard',
    icon: Iconsax.text_block,
    color: Color(0xFFE1F5FE),
    colorDark: Color(0xFF0277BD),
    description: 'Whiteboard notes with perspective correction & glare removal',
    badge: 'Smart Crop',
    badgeIcon: '🖊️',
    scanType: 'whiteboard',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.scan,
  ),
  _TemplateItem(
    name: 'Table Sheet',
    icon: Iconsax.element_3,
    color: Color(0xFFFFF3E0),
    colorDark: Color(0xFFE65100),
    description: 'Structured table with custom columns, rows & CSV export',
    badge: 'CSV · Excel',
    badgeIcon: '📊',
    scanType: 'table',
    route: _TemplateRoute.builder,
    category: _TemplateCategory.scan,
  ),
];

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _search = TextEditingController();
  String _query = '';

  static const _cats = <_TemplateCategory>[
    _TemplateCategory.business,
    _TemplateCategory.legal,
    _TemplateCategory.personal,
    _TemplateCategory.scan,
  ];
  static const _catLabels = ['Business', 'Legal', 'Personal', 'Scan'];
  static const _catIcons = <IconData>[
    Iconsax.briefcase,
    Iconsax.document_text,
    Iconsax.personalcard,
    Iconsax.scan,
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _cats.length + 1, vsync: this);
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  List<_TemplateItem> get _filtered {
    if (_query.isEmpty) return _templates;
    return _templates
        .where((t) =>
            t.name.toLowerCase().contains(_query) ||
            t.description.toLowerCase().contains(_query) ||
            t.badge.toLowerCase().contains(_query))
        .toList();
  }

  List<_TemplateItem> _forCat(_TemplateCategory cat) =>
      _templates.where((t) => t.category == cat).toList();

  void _open(_TemplateItem t) {
    switch (t.route) {
      case _TemplateRoute.invoice:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InvoiceTemplateBuilderScreen()));
        break;
      case _TemplateRoute.builder:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DocumentTemplateBuilderScreen(
                    templateName: t.name, scanType: t.scanType)));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: AppColors.navyDark,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Text(
                'Templates',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B1740), Color(0xFF1A2B7A)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      bottom: 30,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 52, 16, 56),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_templates.length} professional templates',
                              style: GoogleFonts.nunito(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                            ),
                            child: Text(
                              'PDF & Export',
                              style: GoogleFonts.nunito(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildTabBar(),
            ),
          ),
        ],
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _query.isNotEmpty
                  ? _buildGrid(_filtered, bottom)
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _buildGrid(_templates, bottom),
                        ..._cats.map((c) => _buildGrid(_forCat(c), bottom)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.navyDark,
      child: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.gold,
        unselectedLabelColor: Colors.white54,
        indicatorColor: AppColors.gold,
        indicatorWeight: 3,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12.5),
        unselectedLabelStyle:
            GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 12.5),
        tabs: [
          const Tab(text: 'All'),
          ...List.generate(
            _cats.length,
            (i) => Tab(
              child: Row(
                children: [
                  Icon(_catIcons[i], size: 13),
                  const SizedBox(width: 5),
                  Text(_catLabels[i]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: _search,
        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search templates…',
          hintStyle: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Iconsax.search_normal, size: 18, color: AppColors.textMuted),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
                  onTap: () => _search.clear(),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<_TemplateItem> items, double bottomPad) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.document_text,
                size: 48, color: AppColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'No templates found',
              style: GoogleFonts.nunito(
                  color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final cols = MediaQuery.of(context).size.width < 360 ? 1 : 2;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottomPad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) =>
          _TemplateCard(template: items[i], onTap: () => _open(items[i])),
    );
  }
}

// ─────────────────────────────────────────────
//  Card widget
// ─────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final _TemplateItem template;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.onTap});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;

    return GestureDetector(
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: t.colorDark.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Rich visual thumbnail ──
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: _TemplateThumbnail(template: t),
              ),

              // ── Info + CTA inside Expanded (never overflows) ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + icon row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: t.colorDark.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(t.icon, size: 12, color: t.colorDark),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              t.name,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                color: AppColors.textDark,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Description
                      Text(
                        t.description,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.colorDark.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.colorDark.withOpacity(0.2)),
                        ),
                        child: Text(
                          t.badge,
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            color: t.colorDark,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ── CTA button (always at bottom, never overflows) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [t.colorDark, t.colorDark.withOpacity(0.82)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: t.colorDark.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Open Template',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Rich thumbnails (one per template)
// ─────────────────────────────────────────────

class _TemplateThumbnail extends StatelessWidget {
  final _TemplateItem template;
  const _TemplateThumbnail({required this.template});

  @override
  Widget build(BuildContext context) {
    switch (template.name) {
      case 'Invoice':        return _invoice();
      case 'Contract':       return _contract();
      case 'Certificate':    return _certificate();
      case 'Business Card':  return _businessCard();
      case 'Receipt':        return _receipt();
      case 'Whiteboard':     return _whiteboard();
      case 'Resume / CV':    return _resume();
      case 'Meeting Notes':  return _meeting();
      case 'Table Sheet':    return _table();
      default:               return _generic();
    }
  }

  Color get _c => template.colorDark;
  Color get _bg => template.color;

  Widget _line({double w = double.infinity, double h = 5.0, double op = 0.15, Color? color}) =>
      Container(
        height: h,
        width: w,
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: (color ?? Colors.black).withOpacity(op),
          borderRadius: BorderRadius.circular(3),
        ),
      );

  Widget _invoice() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 32,
                decoration: BoxDecoration(
                  color: _c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INVOICE',
                        style: TextStyle(
                            color: _c,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1)),
                    const SizedBox(height: 2),
                    _line(w: 60, h: 4, color: _c, op: 0.4),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: _c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('INV-001',
                    style: TextStyle(color: _c, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
                color: _c.withOpacity(0.07), borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Expanded(child: _line(h: 4, op: 0.12)),
              const SizedBox(width: 4),
              _line(w: 28, h: 4, op: 0.12),
            ]),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _line(h: 4, op: 0.10)),
            const SizedBox(width: 4),
            _line(w: 22, h: 4, op: 0.10),
          ]),
          Row(children: [
            Expanded(child: _line(h: 4, op: 0.08)),
            const SizedBox(width: 4),
            _line(w: 22, h: 4, op: 0.08),
          ]),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _c, borderRadius: BorderRadius.circular(6)),
              child: Text('Total: 15,000',
                  style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _businessCard() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_c, _c.withOpacity(0.80)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: _c.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _line(w: 58, h: 7, color: Colors.white, op: 0.9),
                  _line(w: 40, h: 4, color: Colors.white, op: 0.55),
                ]),
              ]),
              const Spacer(),
              _line(w: 80, h: 4, color: Colors.white, op: 0.5),
              _line(w: 65, h: 4, color: Colors.white, op: 0.4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receipt() {
    return Container(
      height: 110,
      color: _bg,
      child: Center(
        child: Container(
          width: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: _c.withOpacity(0.15), blurRadius: 8)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  height: 16,
                  decoration: BoxDecoration(
                      color: _c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Center(
                      child: Text('RECEIPT',
                          style: TextStyle(
                              color: _c, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5)))),
              const SizedBox(height: 5),
              _line(h: 4, op: 0.12),
              _line(h: 4, op: 0.09),
              const Divider(height: 8, thickness: 0.5),
              _line(h: 4, op: 0.09),
              _line(h: 4, op: 0.09),
              const Divider(height: 8, thickness: 0.5),
              Container(
                  height: 14,
                  decoration: BoxDecoration(
                      color: _c.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Center(
                      child: Text('Total: 620',
                          style: TextStyle(
                              color: _c, fontSize: 7, fontWeight: FontWeight.w800)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contract() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Iconsax.shield_tick, size: 16, color: _c),
            const SizedBox(width: 6),
            Text('LEGAL AGREEMENT',
                style: TextStyle(
                    color: _c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),
          _line(h: 5, op: 0.12),
          _line(h: 4, op: 0.09),
          _line(w: 100, h: 4, op: 0.07),
          const Spacer(),
          Row(children: [
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _c.withOpacity(0.4), width: 1))),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('Party A ______',
                      style: TextStyle(color: _c.withOpacity(0.7), fontSize: 7)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _c.withOpacity(0.4), width: 1))),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('Party B ______',
                      style: TextStyle(color: _c.withOpacity(0.7), fontSize: 7)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _certificate() {
    return Container(
      height: 110,
      color: _bg,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _c.withOpacity(0.50), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.workspace_premium_rounded, color: _c, size: 22),
                  const SizedBox(width: 4),
                  Icon(Icons.star_rounded, color: _c.withOpacity(0.5), size: 10),
                ]),
                const SizedBox(height: 5),
                Text('CERTIFICATE',
                    style: TextStyle(
                        color: _c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text('of Achievement',
                    style: TextStyle(
                        color: _c.withOpacity(0.6), fontSize: 7, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                _line(w: 80, h: 5, color: _c, op: 0.25),
                _line(w: 60, h: 4, color: _c, op: 0.15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resume() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: _c.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, color: _c, size: 16),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line(w: 62, h: 7, color: _c, op: 0.6),
              _line(w: 44, h: 4, color: _c, op: 0.3),
            ]),
          ]),
          const SizedBox(height: 7),
          Container(
            height: 1,
            color: _c.withOpacity(0.15),
          ),
          const SizedBox(height: 5),
          _line(w: 44, h: 5, color: _c, op: 0.3),
          _line(h: 4, op: 0.09),
          _line(w: 85, h: 4, op: 0.07),
        ],
      ),
    );
  }

  Widget _meeting() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Iconsax.note_text, size: 13, color: _c),
            const SizedBox(width: 5),
            Text('MEETING NOTES',
                style: TextStyle(
                    color: _c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 6),
          ...List.generate(
              3,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5, top: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: _c.withOpacity(0.5), width: 1.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(child: _line(h: 4, op: 0.10)),
                    ]),
                  )),
          const Spacer(),
          Container(
            height: 12,
            decoration: BoxDecoration(
                color: _c.withOpacity(0.09), borderRadius: BorderRadius.circular(4)),
            child: Center(
                child: Text('Action Items',
                    style: TextStyle(color: _c, fontSize: 7, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
    );
  }

  Widget _whiteboard() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: _c.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                child: Icon(Iconsax.text_block, size: 10, color: _c),
              ),
              const SizedBox(width: 5),
              _line(w: 60, h: 6, color: _c, op: 0.5),
            ]),
            const SizedBox(height: 6),
            _line(h: 4, op: 0.10),
            _line(w: 90, h: 4, op: 0.08),
            _line(w: 70, h: 4, op: 0.06),
            const Spacer(),
            _line(w: 50, h: 4, color: _c, op: 0.25),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    return Container(
      height: 110,
      color: _bg,
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        // Header row
        Container(
          height: 20,
          decoration: BoxDecoration(
              color: _c, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
          child: Row(children: [
            _tableCell('Item', isHeader: true),
            _tableCell('Qty', isHeader: true),
            _tableCell('Value', isHeader: true),
          ]),
        ),
        // Data rows
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: _c.withOpacity(0.15)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(6))),
            child: Column(children: [
              Expanded(child: Row(children: [
                _tableCell('Alpha'), _tableCell('12'), _tableCell('5,000'),
              ])),
              Divider(height: 1, color: _c.withOpacity(0.1)),
              Expanded(child: Row(children: [
                _tableCell('Beta'), _tableCell('8'), _tableCell('3,200'),
              ])),
              Divider(height: 1, color: _c.withOpacity(0.1)),
              Expanded(child: Row(children: [
                _tableCell('Gamma'), _tableCell('5'), _tableCell('2,100'),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
              color: isHeader ? Colors.white : _c.withOpacity(0.7),
              fontSize: 7,
              fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _generic() {
    return Container(
      height: 110,
      color: _bg,
      child: Center(
        child: Icon(template.icon, size: 36, color: _c.withOpacity(0.4)),
      ),
    );
  }
}
