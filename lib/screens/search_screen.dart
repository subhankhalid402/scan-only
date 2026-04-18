import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import 'document_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<DocumentModel> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await DatabaseService.instance.searchDocuments(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Color _accentForDoc(DocumentModel doc) {
    final t = doc.fileType.toLowerCase();
    if (t == 'pdf') return const Color(0xFFDC2626);
    if (t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'webp') {
      return const Color(0xFF2563EB);
    }
    return AppColors.navyMid;
  }

  IconData _iconForDoc(DocumentModel doc) {
    final t = doc.fileType.toLowerCase();
    if (t == 'pdf') return Iconsax.document;
    if (t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'webp') {
      return Iconsax.gallery;
    }
    return Iconsax.document_text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navyDark, AppColors.navyMid, Color(0xFF1E3A5F)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Iconsax.search_normal,
                              color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Search',
                                style: GoogleFonts.nunito(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Name, tags & OCR text — on your device',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: _search,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E2A4A),
                        ),
                        cursorColor: AppColors.navyDark,
                        decoration: InputDecoration(
                          hintText: 'Search documents…',
                          hintStyle: GoogleFonts.nunito(
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Iconsax.search_normal,
                                color: AppColors.navyMid, size: 22),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: Colors.grey.shade500, size: 22),
                                  onPressed: () {
                                    _controller.clear();
                                    _search('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _controller.text.isEmpty
                ? _buildEmptyState()
                : _isSearching
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                color: AppColors.navyMid,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Searching library…',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? _buildNoResults()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    void tryQuery(String q) {
      _controller.text = q;
      _search(q);
      setState(() {});
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.25),
                    AppColors.navyMid.withValues(alpha: 0.12),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyDark.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(Iconsax.search_status,
                  size: 48, color: AppColors.navyDark.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 22),
            Text(
              'Find anything in your scans',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E2A4A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Type a word from a receipt, ID field, or file name. Everything stays on-device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'QUICK TRY',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('Receipt', tryQuery),
                _suggestionChip('Invoice', tryQuery),
                _suggestionChip('Passport', tryQuery),
                _suggestionChip('Contract', tryQuery),
                _suggestionChip('Tax', tryQuery),
                _suggestionChip('Work', tryQuery),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, void Function(String) onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () => onTap(label),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.navyDark.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: const Color(0xFF1E2A4A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.document_cloud,
                size: 72, color: Colors.blueGrey.shade100),
            const SizedBox(height: 18),
            Text(
              'No matches',
              style: GoogleFonts.nunito(
                fontSize: 18,
                color: const Color(0xFF1E2A4A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a shorter word, check spelling, or search part of a file name.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                _controller.clear();
                _search('');
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navyDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Iconsax.refresh, size: 18),
              label: Text(
                'Clear search',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final dateFmt = DateFormat('MMM d, yyyy');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final doc = _results[i];
        final accent = _accentForDoc(doc);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentViewerScreen(document: doc),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.navyDark.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconForDoc(doc), color: accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E2A4A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${doc.fileType.toUpperCase()} · ${doc.pageCount} pg · ${doc.fileSizeMB.toStringAsFixed(1)} MB',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(doc.createdAt),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Iconsax.arrow_right_3,
                        color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
