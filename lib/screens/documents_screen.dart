import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import 'document_viewer_screen.dart';
import 'import_documents_screen.dart';

class DocumentsScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  const DocumentsScreen({super.key, this.onRefresh});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DocumentModel> _allDocs = [];
  List<DocumentModel> _favDocs = [];
  bool _isGridView = false;
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDocs();
    _syncGridFromSettings();
  }

  Future<void> _syncGridFromSettings() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isGridView = p.getBool('gridView') ?? false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocs() async {
    final all  = await DatabaseService.instance.getAllDocuments();
    final favs = await DatabaseService.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _allDocs  = _sortDocs(all);
      _favDocs  = _sortDocs(favs);
    });
    widget.onRefresh?.call();
  }

  List<DocumentModel> _sortDocs(List<DocumentModel> docs) {
    final list = List<DocumentModel>.from(docs);
    switch (_sortBy) {
      case 'name': list.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'size': list.sort((a, b) => b.fileSizeMB.compareTo(a.fileSizeMB)); break;
      default:     list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<void> _toggleFavorite(DocumentModel doc) async {
    await DatabaseService.instance.toggleFavorite(doc.id!, !doc.isFavorite);
    _loadDocs();
  }

  Future<void> _deleteDoc(DocumentModel doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Document', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Delete "${doc.name}"? This cannot be undone.',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.deleteDocument(doc.id!);
      _loadDocs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyDark, AppColors.navyMid],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Text('My Documents',
                          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const Spacer(),
                        // Import button
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ImportDocumentsScreen()),
                            ).then((_) => _loadDocs());
                          },
                          icon: const Icon(Iconsax.import, color: Colors.white, size: 22),
                        ),
                        // Grid/List toggle
                        IconButton(
                          onPressed: () async {
                            setState(() => _isGridView = !_isGridView);
                            final p = await SharedPreferences.getInstance();
                            await p.setBool('gridView', _isGridView);
                          },
                          icon: Icon(
                            _isGridView ? Iconsax.row_vertical : Iconsax.grid_2,
                            color: Colors.white, size: 22),
                        ),
                        // Sort
                        PopupMenuButton<String>(
                          icon: const Icon(Iconsax.sort, color: Colors.white, size: 22),
                          onSelected: (val) {
                            setState(() => _sortBy = val);
                            _loadDocs();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'date', child: Text('Sort by Date')),
                            PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                            PopupMenuItem(value: 'size', child: Text('Sort by Size')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.gold,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'All (${_allDocs.length})'),
                      Tab(text: 'Favorites (${_favDocs.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDocList(_allDocs),
                _buildDocList(_favDocs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocList(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.document, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No documents found',
              style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: docs.length,
        itemBuilder: (_, i) => _DocGridCard(
          doc: docs[i],
          onTap: () => _openDoc(docs[i]),
          onFavorite: () => _toggleFavorite(docs[i]),
          onDelete: () => _deleteDoc(docs[i]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        return Slidable(
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => _toggleFavorite(doc),
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navyDark,
                icon: doc.isFavorite ? Iconsax.heart_slash : Iconsax.heart,
                label: doc.isFavorite ? 'Unfav' : 'Fav',
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              SlidableAction(
                onPressed: (_) => _deleteDoc(doc),
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                icon: Iconsax.trash,
                label: 'Delete',
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              ),
            ],
          ),
          child: _DocListCard(
            doc: doc,
            onTap: () => _openDoc(doc),
            onFavorite: () => _toggleFavorite(doc),
            onDelete: () => _deleteDoc(doc),
          ),
        );
      },
    );
  }

  void _openDoc(DocumentModel doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc)),
    );
    _loadDocs();
  }
}

// ─── List Card ────────────────────────────────────────────────────────────

class _DocListCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _DocListCard({
    required this.doc, required this.onTap,
    required this.onFavorite, required this.onDelete,
  });

  Color get _iconColor {
    if (doc.fileType == 'pdf') return AppColors.red;
    if (doc.fileType == 'jpg' || doc.fileType == 'png') return AppColors.blue;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              width: 50, height: 50,
              decoration: BoxDecoration(color: _iconColor, borderRadius: BorderRadius.circular(14)),
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
                  Text(
                    '${DateFormat('MMM d, yyyy').format(doc.createdAt)} • ${doc.pageCount} page${doc.pageCount > 1 ? 's' : ''} • ${doc.fileSizeMB.toStringAsFixed(1)} MB',
                    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                doc.isFavorite ? Iconsax.heart5 : Iconsax.heart,
                color: doc.isFavorite ? AppColors.red : Colors.grey,
                size: 20),
              onPressed: onFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid Card ────────────────────────────────────────────────────────────

class _DocGridCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _DocGridCard({
    required this.doc, required this.onTap,
    required this.onFavorite, required this.onDelete,
  });

  Color get _iconColor {
    if (doc.fileType == 'pdf') return AppColors.red;
    if (doc.fileType == 'jpg' || doc.fileType == 'png') return AppColors.blue;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _iconColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Image.file(File(doc.thumbnailPath!), fit: BoxFit.cover, width: double.infinity),
                            )
                          : Icon(Iconsax.document_text, size: 50, color: _iconColor),
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          doc.isFavorite ? Iconsax.heart5 : Iconsax.heart,
                          color: doc.isFavorite ? AppColors.red : Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.name,
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(doc.fileType.toUpperCase(),
                          style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w800, color: _iconColor)),
                      ),
                      const SizedBox(width: 5),
                      Text('${doc.fileSizeMB.toStringAsFixed(1)}MB',
                        style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
