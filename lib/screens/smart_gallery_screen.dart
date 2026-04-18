import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/share_file_service.dart';
import '../services/smart_gallery_service.dart';
import '../services/watermark_service.dart';
import '../theme.dart';
import 'document_viewer_screen.dart';
import 'import_documents_screen.dart';

class SmartGalleryScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  final int refreshToken;
  const SmartGalleryScreen({super.key, this.onRefresh, this.refreshToken = 0});

  @override
  State<SmartGalleryScreen> createState() => _SmartGalleryScreenState();
}

class _SmartGalleryScreenState extends State<SmartGalleryScreen> {
  List<DocumentModel> _all = [];
  List<DocumentModel> _shown = [];
  final _q = TextEditingController();
  bool _grid = true;
  bool _bulk = false;
  final Set<int> _selected = {};
  String _category = 'All';
  String _sort = 'date';
  String _fileType = 'all';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
    _load();
  }

  @override
  void didUpdateWidget(covariant SmartGalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final docs = await SmartGalleryService.instance.loadAll();
    if (!mounted) return;
    setState(() {
      _all = docs;
      _applyFilters();
    });
    widget.onRefresh?.call();
  }

  void _applyFilters() {
    var out = List<DocumentModel>.from(_all);
    final q = _q.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((d) {
        final combined =
            '${d.name} ${d.scanType} ${d.fileType} ${d.tags.join(' ')} ${d.ocrText ?? ''}'
                .toLowerCase();
        return combined.contains(q);
      }).toList();
    }
    if (_category != 'All') {
      out = out
          .where(
              (d) => SmartGalleryService.instance.categoryFor(d) == _category)
          .toList();
    }
    if (_fileType != 'all') {
      out = out.where((d) => d.fileType.toLowerCase() == _fileType).toList();
    }
    if (_range != null) {
      out = out.where((d) {
        final dt = d.createdAt;
        return !dt.isBefore(_range!.start) &&
            !dt.isAfter(_range!.end.add(const Duration(days: 1)));
      }).toList();
    }
    switch (_sort) {
      case 'name':
        out.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'size':
        out.sort((a, b) => b.fileSizeMB.compareTo(a.fileSizeMB));
        break;
      default:
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    _shown = out;
  }

  List<String> _categories() {
    final set = <String>{'All'};
    for (final d in _all) {
      set.add(SmartGalleryService.instance.categoryFor(d));
    }
    return set.toList();
  }

  List<DocumentModel> get _selectedDocs =>
      _shown.where((d) => d.id != null && _selected.contains(d.id)).toList();

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

  Future<void> _toggleFavorite(DocumentModel d) async {
    if (d.id == null) return;
    await DatabaseService.instance.toggleFavorite(d.id!, !d.isFavorite);
    _load();
  }

  Future<void> _deleteSelected() async {
    if (_selectedDocs.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Delete selected',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Delete ${_selectedDocs.length} file(s)? This cannot be undone.',
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
    if (confirm != true || !mounted) return;
    for (final d in _selectedDocs) {
      if (d.id == null) continue;
      await DatabaseService.instance.deleteDocument(d.id!);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _bulk = false;
    });
    _load();
  }

  Future<void> _shareSelected() async {
    final paths = _selectedDocs
        .where((d) => File(d.filePath).existsSync())
        .map((d) => d.filePath)
        .toList();
    if (paths.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No files found to share.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final n = await ShareFileService.sharePaths(
      paths,
      text: paths.length == 1 ? 'Shared from Smart Gallery' : null,
    );
    if (!mounted) return;
    if (n == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not share files.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (n < _selectedDocs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Shared $n file(s). Some files were missing.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _zipSelected() async {
    final path = await SmartGalleryService.instance.exportZip(_selectedDocs);
    if (path == null || !mounted) return;
    await ShareFileService.sharePaths([path], text: 'Smart Gallery ZIP');
  }

  Future<void> _mergePdfSelected() async {
    final path = await SmartGalleryService.instance.mergeAsPdf(_selectedDocs);
    if (path == null || !mounted) return;
    await ShareFileService.sharePaths([path], text: 'Merged PDF');
  }

  Future<void> _tagSelected(String tag) async {
    await SmartGalleryService.instance.applyTag(_selectedDocs, tag);
    _load();
  }

  Future<void> _watermarkSelected() async {
    final rasters = _selectedDocs
        .where((d) =>
            const {'jpg', 'jpeg', 'png'}.contains(d.fileType.toLowerCase()))
        .toList();
    if (rasters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select JPG/PNG files for watermark.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    for (final d in rasters) {
      final out = await WatermarkService.instance.addTextWatermark(
        d.filePath,
        text: 'CONFIDENTIAL',
        red: 229,
        green: 57,
        blue: 53,
        opacity: 95,
      );
      if (d.id != null) {
        await DatabaseService.instance.updateDocument(
          d.copyWith(
            filePath: out,
            modifiedAt: DateTime.now(),
          ),
        );
      }
    }
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.navyDark,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF1E2A4A),
          ),
        ),
        child: child!,
      ),
    );
    if (r == null) return;
    setState(() {
      _range = r;
      _applyFilters();
    });
  }

  Future<void> _cleanupStorage() async {
    final n = await SmartGalleryService.instance.cleanupOldTempFiles();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed $n old temp files',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = SmartGalleryService.instance.groupByScanDate(_shown);
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          if (_bulk) _buildBulkBar(),
          Expanded(
            child: _grid ? _buildGrid(grouped) : _buildList(grouped),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navyDark,
            AppColors.navyMid,
            Color(0xFF1E3A5F),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Iconsax.gallery,
                      color: AppColors.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Smart Gallery',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Import',
                    iconSize: 22,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ImportDocumentsScreen()),
                      ).then((_) => _load());
                    },
                    icon: const Icon(Iconsax.import, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: _grid ? 'List view' : 'Grid view',
                    iconSize: 22,
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: Icon(
                      _grid ? Iconsax.row_vertical : Iconsax.grid_2,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: _bulk ? 'Exit selection' : 'Select multiple',
                    iconSize: 22,
                    onPressed: () => setState(() {
                      _bulk = !_bulk;
                      if (!_bulk) _selected.clear();
                    }),
                    icon: Icon(
                      _bulk ? Iconsax.close_circle : Iconsax.tick_square,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 1,
                shadowColor: Colors.black26,
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(_applyFilters),
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E2A4A),
                  ),
                  cursorColor: AppColors.navyDark,
                  decoration: InputDecoration(
                    hintText: 'Search name, tags, scan type, OCR…',
                    hintStyle: GoogleFonts.nunito(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Iconsax.search_normal,
                      color: AppColors.navyMid,
                      size: 22,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    suffixIcon: _q.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.grey.shade600,
                              size: 22,
                            ),
                            onPressed: () {
                              _q.clear();
                              setState(_applyFilters);
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories().length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = _categories()[i];
                    return _headerFilterChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() {
                        _category = c;
                        _applyFilters();
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickRange,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Iconsax.calendar, size: 20),
                      label: Text(
                        _range == null
                            ? 'Date range'
                            : '${DateFormat('dd MMM').format(_range!.start)} – ${DateFormat('dd MMM').format(_range!.end)}',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'File type',
                    onSelected: (v) => setState(() {
                      _fileType = v;
                      _applyFilters();
                    }),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'all',
                        child: Text('All types',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuItem(
                        value: 'pdf',
                        child: Text('PDF',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuItem(
                        value: 'jpg',
                        child: Text('JPG',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuItem(
                        value: 'png',
                        child: Text('PNG',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuItem(
                        value: 'xlsx',
                        child: Text('Excel',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    child: _headerMenuChip('Type', _fileType),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Sort',
                    onSelected: (v) => setState(() {
                      _sort = v;
                      _applyFilters();
                    }),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'date',
                        child: Text('Sort by date',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuItem(
                        value: 'name',
                        child: Text('Sort by name',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuItem(
                        value: 'size',
                        child: Text('Sort by size',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    child: _headerMenuChip('Sort', _sort),
                  ),
                  IconButton(
                    tooltip: 'Clean old temp files',
                    iconSize: 22,
                    onPressed: _cleanupStorage,
                    icon: const Icon(Iconsax.broom, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              color: selected ? AppColors.gold : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerMenuChip(String prefix, String value) {
    return SizedBox(
      height: 44,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$prefix: ',
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkBar() {
    return Material(
      color: AppColors.navyDark,
      elevation: 2,
      shadowColor: Colors.black26,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_selected.length} selected',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _bulkBtn(
              icon: Iconsax.share,
              label: 'Share',
              onPressed: _selected.isEmpty ? null : _shareSelected,
            ),
            _bulkBtn(
              icon: Iconsax.tag,
              label: 'Private',
              onPressed: _selected.isEmpty ? null : () => _tagSelected('private'),
            ),
            _bulkBtn(
              icon: Iconsax.tag,
              label: 'Work',
              onPressed: _selected.isEmpty ? null : () => _tagSelected('Work'),
            ),
            _bulkBtn(
              icon: Iconsax.document_cloud,
              label: 'ZIP',
              onPressed: _selected.isEmpty ? null : _zipSelected,
            ),
            _bulkBtn(
              icon: Iconsax.document,
              label: 'Merge PDF',
              onPressed: _selected.isEmpty ? null : _mergePdfSelected,
            ),
            _bulkBtn(
              icon: Iconsax.text,
              label: 'Watermark',
              onPressed: _selected.isEmpty ? null : _watermarkSelected,
            ),
            _bulkBtn(
              icon: Iconsax.trash,
              label: 'Delete',
              filled: true,
              onPressed: _selected.isEmpty ? null : _deleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulkBtn({
    required IconData icon,
    required String label,
    required Future<void> Function()? onPressed,
    bool filled = false,
  }) {
    if (filled) {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildGrid(Map<DateTime, List<DocumentModel>> grouped) {
    final flat = grouped.values.expand((e) => e).toList();
    if (flat.isEmpty) return _emptyState();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: flat.length,
      itemBuilder: (_, i) => _gridCard(flat[i]),
    );
  }

  Widget _buildList(Map<DateTime, List<DocumentModel>> grouped) {
    if (grouped.isEmpty) return _emptyState();
    final keys = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        final docs = grouped[k]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 10, top: i == 0 ? 0 : 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEE, dd MMM yyyy').format(k),
                    style: GoogleFonts.nunito(
                      color: const Color(0xFF1E2A4A),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...docs.map(_listRow),
          ],
        );
      },
    );
  }

  Widget _listRow(DocumentModel d) {
    final selected = d.id != null && _selected.contains(d.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bulk ? _toggleSelect(d) : _open(d),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.gold
                    : AppColors.navyDark.withValues(alpha: 0.06),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: _thumb(d, fit: BoxFit.cover, full: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.25,
                            color: const Color(0xFF1E2A4A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${SmartGalleryService.instance.categoryFor(d)} · ${d.fileType.toUpperCase()} · ${d.fileSizeMB.toStringAsFixed(1)} MB · ${d.pageCount} pg',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_bulk)
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.gold : Colors.grey.shade400,
                      size: 24,
                    )
                  else
                    IconButton(
                      tooltip: 'Favorite',
                      onPressed: () => _toggleFavorite(d),
                      icon: Icon(
                        d.isFavorite ? Iconsax.heart5 : Iconsax.heart,
                        color: d.isFavorite ? AppColors.gold : Colors.grey,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridCard(DocumentModel d) {
    final selected = d.id != null && _selected.contains(d.id);
    final accent = _accentForDoc(d);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _bulk ? _toggleSelect(d) : _open(d),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : AppColors.navyDark.withValues(alpha: 0.06),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumb(d, fit: BoxFit.cover, full: true),
                    if (!_bulk)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _toggleFavorite(d),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                d.isFavorite ? Iconsax.heart5 : Iconsax.heart,
                                size: 16,
                                color: d.isFavorite ? AppColors.gold : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_bulk)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selected ? Icons.check : Icons.circle_outlined,
                            color: selected ? AppColors.gold : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: const Color(0xFF1E2A4A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconForDoc(d), size: 12, color: accent),
                              const SizedBox(width: 4),
                              Text(
                                d.fileType.toUpperCase(),
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${d.pageCount} pg',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _thumb(DocumentModel d,
      {BoxFit fit = BoxFit.cover, bool full = false}) {
    final file = d.thumbnailPath != null && File(d.thumbnailPath!).existsSync()
        ? File(d.thumbnailPath!)
        : null;
    final accent = _accentForDoc(d);
    if (file == null) {
      return Container(
        width: full ? double.infinity : 52,
        height: full ? double.infinity : 52,
        color: accent.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Icon(_iconForDoc(d), color: accent, size: full ? 40 : 24),
      );
    }
    return Image.file(
      file,
      fit: fit,
      width: full ? double.infinity : 52,
      height: full ? double.infinity : 52,
      cacheWidth: full ? 400 : 128,
      filterQuality: FilterQuality.low,
    );
  }

  void _toggleSelect(DocumentModel d) {
    if (d.id == null) return;
    setState(() {
      if (_selected.contains(d.id)) {
        _selected.remove(d.id);
      } else {
        _selected.add(d.id!);
      }
    });
  }

  Future<void> _open(DocumentModel d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: d)),
    );
    _load();
  }

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.22),
                    AppColors.navyMid.withValues(alpha: 0.1),
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
              child: Icon(
                Iconsax.image,
                size: 44,
                color: AppColors.navyDark.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Nothing matches',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E2A4A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try another category, clear the search, or import files to build your gallery.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ImportDocumentsScreen()),
                ).then((_) => _load());
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navyDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Iconsax.import, size: 20),
              label: Text(
                'Import documents',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
