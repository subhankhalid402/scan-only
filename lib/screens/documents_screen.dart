import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_local_storage.dart';
import '../theme.dart';
import '../models/document_model.dart';
import '../services/database_service.dart';
import 'document_viewer_screen.dart';
import 'import_documents_screen.dart';

class DocumentsScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  final int refreshToken;
  const DocumentsScreen({super.key, this.onRefresh, this.refreshToken = 0});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentModel> _allDocs = [];
  bool _isGridView = false;
  String _sortBy = 'date';
  String _selectedFilter = 'all';
  bool _bulkMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDocs();
    _syncGridFromSettings();
  }

  @override
  void didUpdateWidget(covariant DocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadDocs();
    }
  }

  Future<void> _syncGridFromSettings() async {
    if (!mounted) return;
    setState(() => _isGridView = AppLocalStorage.getBool('gridView'));
  }

  @override
  void dispose() => super.dispose();

  Future<void> _loadDocs() async {
    final all = await DatabaseService.instance.getAllDocuments();
    if (!mounted) return;
    setState(() {
      _allDocs = _sortDocs(all);
    });
    widget.onRefresh?.call();
  }

  List<DocumentModel> _sortDocs(List<DocumentModel> docs) {
    final list = List<DocumentModel>.from(docs);
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'size':
        list.sort((a, b) => b.fileSizeMB.compareTo(a.fileSizeMB));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<void> _toggleFavorite(DocumentModel doc) async {
    await DatabaseService.instance.toggleFavorite(doc.id!, !doc.isFavorite);
    _loadDocs();
  }

  List<DocumentModel> _filteredDocs() {
    switch (_selectedFilter) {
      case 'pdf':
        return _allDocs
            .where((d) => d.fileType.toLowerCase() == 'pdf')
            .toList();
      case 'images':
        return _allDocs.where((d) {
          final t = d.fileType.toLowerCase();
          return t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'webp';
        }).toList();
      case 'recent':
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        return _allDocs.where((d) => d.createdAt.isAfter(cutoff)).toList();
      case 'favorites':
        return _allDocs.where((d) => d.isFavorite).toList();
      default:
        return _allDocs;
    }
  }

  int _countFor(String filterId) {
    switch (filterId) {
      case 'all':
        return _allDocs.length;
      case 'pdf':
        return _allDocs.where((d) => d.fileType.toLowerCase() == 'pdf').length;
      case 'images':
        return _allDocs.where((d) {
          final t = d.fileType.toLowerCase();
          return t == 'jpg' || t == 'jpeg' || t == 'png' || t == 'webp';
        }).length;
      case 'recent':
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        return _allDocs.where((d) => d.createdAt.isAfter(cutoff)).length;
      case 'favorites':
        return _allDocs.where((d) => d.isFavorite).length;
      default:
        return 0;
    }
  }

  Future<void> _deleteDoc(DocumentModel doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Document',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Delete "${doc.name}"? This cannot be undone.',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.deleteDocument(doc.id!);
      _loadDocs();
    }
  }

  List<DocumentModel> get _selectedDocs => _allDocs
      .where((d) => d.id != null && _selectedIds.contains(d.id))
      .toList();

  void _toggleSelect(DocumentModel doc) {
    if (doc.id == null) return;
    setState(() {
      if (_selectedIds.contains(doc.id)) {
        _selectedIds.remove(doc.id);
      } else {
        _selectedIds.add(doc.id!);
      }
    });
  }

  Future<void> _shareSelected() async {
    final files = _selectedDocs
        .where((d) => File(d.filePath).existsSync())
        .map((d) => XFile(d.filePath))
        .toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files, text: 'Shared from ScanOnly');
  }

  Future<void> _deleteSelected() async {
    if (_selectedDocs.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Delete Selected',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Delete ${_selectedDocs.length} selected file(s)? This cannot be undone.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final d in _selectedDocs) {
      if (d.id == null) continue;
      await DatabaseService.instance.deleteDocument(d.id!);
    }
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _bulkMode = false;
    });
    _loadDocs();
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text('My Documents',
                            style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const Spacer(),
                        // Import button
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ImportDocumentsScreen()),
                            ).then((_) => _loadDocs());
                          },
                          icon: const Icon(Iconsax.import,
                              color: Colors.white, size: 22),
                        ),
                        // Grid/List toggle
                        IconButton(
                          onPressed: () async {
                            setState(() => _isGridView = !_isGridView);
                            await AppLocalStorage.setBool(
                                'gridView', _isGridView);
                          },
                          icon: Icon(
                              _isGridView
                                  ? Iconsax.row_vertical
                                  : Iconsax.grid_2,
                              color: Colors.white,
                              size: 22),
                        ),
                        // Sort
                        PopupMenuButton<String>(
                          icon: const Icon(Iconsax.sort,
                              color: Colors.white, size: 22),
                          onSelected: (val) {
                            setState(() => _sortBy = val);
                            _loadDocs();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'date', child: Text('Sort by Date')),
                            PopupMenuItem(
                                value: 'name', child: Text('Sort by Name')),
                            PopupMenuItem(
                                value: 'size', child: Text('Sort by Size')),
                          ],
                        ),
                        IconButton(
                          tooltip:
                              _bulkMode ? 'Exit multi-select' : 'Multi-select',
                          onPressed: () => setState(() {
                            _bulkMode = !_bulkMode;
                            if (!_bulkMode) _selectedIds.clear();
                          }),
                          icon: Icon(
                            _bulkMode
                                ? Iconsax.close_circle
                                : Iconsax.tick_square,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterTab('all', 'All'),
                        _buildFilterTab('pdf', 'PDF'),
                        _buildFilterTab('images', 'Images'),
                        _buildFilterTab('recent', 'Recent'),
                        _buildFilterTab('favorites', 'Favorites'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: Column(
              children: [
                if (_bulkMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: AppColors.navyDark,
                    child: Row(
                      children: [
                        Text(
                          '${_selectedIds.length} selected',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed:
                              _selectedIds.isEmpty ? null : _shareSelected,
                          icon: const Icon(Iconsax.share, size: 16),
                          label: const Text('Share'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed:
                              _selectedIds.isEmpty ? null : _deleteSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Iconsax.trash, size: 16),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildDocList(_filteredDocs())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.gold : Colors.white24,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            '$label (${_countFor(id)})',
            style: GoogleFonts.nunito(
              color: isSelected ? AppColors.gold : Colors.white70,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
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
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.86,
        ),
        itemCount: docs.length,
        itemBuilder: (_, i) => _DocGridCard(
          doc: docs[i],
          onTap: () => _bulkMode ? _toggleSelect(docs[i]) : _openDoc(docs[i]),
          onLongPress: () => _toggleSelect(docs[i]),
          bulkMode: _bulkMode,
          selected: docs[i].id != null && _selectedIds.contains(docs[i].id),
          onFavorite: () => _toggleFavorite(docs[i]),
          onDelete: () => _deleteDoc(docs[i]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        if (_bulkMode) {
          return _DocListCard(
            doc: doc,
            onTap: () => _toggleSelect(doc),
            onLongPress: () => _toggleSelect(doc),
            bulkMode: true,
            selected: doc.id != null && _selectedIds.contains(doc.id),
            onFavorite: () => _toggleFavorite(doc),
            onDelete: () => _deleteDoc(doc),
          );
        }
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
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              SlidableAction(
                onPressed: (_) => _deleteDoc(doc),
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                icon: Iconsax.trash,
                label: 'Delete',
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(16)),
              ),
            ],
          ),
          child: _DocListCard(
            doc: doc,
            onTap: () => _openDoc(doc),
            onLongPress: () => _toggleSelect(doc),
            bulkMode: false,
            selected: false,
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
  final VoidCallback onLongPress;
  final bool bulkMode;
  final bool selected;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _DocListCard({
    required this.doc,
    required this.onTap,
    required this.onLongPress,
    required this.bulkMode,
    required this.selected,
    required this.onFavorite,
    required this.onDelete,
  });

  Color get _iconColor {
    if (doc.fileType == 'pdf') return AppColors.navyDark;
    if (doc.fileType == 'jpg' || doc.fileType == 'png') {
      return AppColors.navyMid;
    }
    return AppColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _iconColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Iconsax.document_text,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.name,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${DateFormat('MMM d, yyyy').format(doc.createdAt)} • ${doc.pageCount} page${doc.pageCount > 1 ? 's' : ''} • ${doc.fileSizeMB.toStringAsFixed(1)} MB',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: bulkMode ? 'Selected' : 'Favorite',
              icon: bulkMode
                  ? Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? AppColors.gold : Colors.grey,
                      size: 22,
                    )
                  : Icon(
                      doc.isFavorite ? Iconsax.heart5 : Iconsax.heart,
                      color: doc.isFavorite ? AppColors.gold : Colors.grey,
                      size: 20,
                    ),
              onPressed: bulkMode ? onTap : onFavorite,
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
  final VoidCallback onLongPress;
  final bool bulkMode;
  final bool selected;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _DocGridCard({
    required this.doc,
    required this.onTap,
    required this.onLongPress,
    required this.bulkMode,
    required this.selected,
    required this.onFavorite,
    required this.onDelete,
  });

  Color get _iconColor {
    if (doc.fileType == 'pdf') return AppColors.navyDark;
    if (doc.fileType == 'jpg' || doc.fileType == 'png') {
      return AppColors.navyMid;
    }
    return AppColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _iconColor.withValues(alpha: 0.1),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: doc.thumbnailPath != null &&
                              File(doc.thumbnailPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              child: Image.file(
                                File(doc.thumbnailPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : Icon(Iconsax.document_text,
                              size: 50, color: _iconColor),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onFavorite,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: bulkMode
                              ? Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color:
                                      selected ? AppColors.gold : Colors.grey,
                                  size: 16,
                                )
                              : Icon(
                                  doc.isFavorite
                                      ? Iconsax.heart5
                                      : Iconsax.heart,
                                  color: doc.isFavorite
                                      ? AppColors.gold
                                      : Colors.grey,
                                  size: 16,
                                ),
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
                  Text(
                    doc.name,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.fileType.toUpperCase(),
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${doc.fileSizeMB.toStringAsFixed(1)}MB',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
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
