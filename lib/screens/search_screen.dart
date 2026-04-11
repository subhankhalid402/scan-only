import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
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

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    final results = await DatabaseService.instance.searchDocuments(query);
    setState(() { _results = results; _isSearching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyDark, AppColors.navyMid],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Search',
                      style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: _search,
                        decoration: InputDecoration(
                          hintText: 'Search documents, text...',
                          hintStyle: GoogleFonts.nunito(color: Colors.grey),
                          prefixIcon: const Icon(Iconsax.search_normal, color: AppColors.navyMid),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () { _controller.clear(); _search(''); },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    ? const Center(child: CircularProgressIndicator(color: AppColors.navyMid))
                    : _results.isEmpty
                        ? _buildNoResults()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.search_normal, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Search your documents',
            style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Search by name, date, or content',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document_cloud, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No results found',
            style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          Text('Try different keywords',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final doc = _results[i];
        return GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: doc.fileType == 'pdf' ? AppColors.red : AppColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.document_text, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.name,
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('${doc.fileType.toUpperCase()} • ${doc.pageCount} pages • ${doc.fileSizeMB.toStringAsFixed(1)} MB',
                        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Iconsax.arrow_right_3, color: Colors.grey, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
