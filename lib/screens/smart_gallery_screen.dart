import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_model.dart';
import '../services/database_service.dart';
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

  Future<void> _toggleFavorite(DocumentModel d) async {
    if (d.id == null) return;
    await DatabaseService.instance.toggleFavorite(d.id!, !d.isFavorite);
    _load();
  }

  Future<void> _deleteSelected() async {
    for (final d in _selectedDocs) {
      if (d.id == null) continue;
      await DatabaseService.instance.deleteDocument(d.id!);
    }
    setState(() => _selected.clear());
    _load();
  }

  Future<void> _shareSelected() async {
    final files = _selectedDocs.map((d) => XFile(d.filePath)).toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files, text: 'Shared from Smart Gallery');
  }

  Future<void> _zipSelected() async {
    final path = await SmartGalleryService.instance.exportZip(_selectedDocs);
    if (path == null || !mounted) return;
    await Share.shareXFiles([XFile(path)], text: 'Smart Gallery ZIP');
  }

  Future<void> _mergePdfSelected() async {
    final path = await SmartGalleryService.instance.mergeAsPdf(_selectedDocs);
    if (path == null || !mounted) return;
    await Share.shareXFiles([XFile(path)], text: 'Merged PDF');
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
        const SnackBar(content: Text('Select JPG/PNG files for watermark.')),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Removed $n old temp files')));
  }

  @override
  Widget build(BuildContext context) {
    final usage = SmartGalleryService.instance.totalStorageMB(_all);
    final dupCount = SmartGalleryService.instance.detectDuplicates(_all).length;
    final grouped = SmartGalleryService.instance.groupByScanDate(_shown);
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.navyDark, AppColors.navyMid]),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Smart Gallery',
                            style: GoogleFonts.nunito(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ImportDocumentsScreen()),
                            ).then((_) => _load());
                          },
                          icon: const Icon(Iconsax.import, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _grid = !_grid),
                          icon: Icon(
                              _grid ? Iconsax.row_vertical : Iconsax.grid_2,
                              color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _bulk = !_bulk;
                            if (!_bulk) _selected.clear();
                          }),
                          icon: Icon(
                              _bulk
                                  ? Iconsax.close_circle
                                  : Iconsax.tick_square,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _q,
                      onChanged: (_) => setState(_applyFilters),
                      style: GoogleFonts.nunito(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search filename, OCR text, tags',
                        hintStyle: GoogleFonts.nunito(color: Colors.white54),
                        prefixIcon: const Icon(Iconsax.search_normal,
                            color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _pill('Storage ${usage.toStringAsFixed(1)} MB'),
                        const SizedBox(width: 6),
                        _pill('Duplicates $dupCount'),
                        const SizedBox(width: 6),
                        _pill('Items ${_shown.length}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _categories())
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: _category == c,
                                onSelected: (_) => setState(() {
                                  _category = c;
                                  _applyFilters();
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Iconsax.calendar),
                          label: Text(_range == null
                              ? 'Date range'
                              : '${DateFormat('dd MMM').format(_range!.start)} - ${DateFormat('dd MMM').format(_range!.end)}'),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) => setState(() {
                            _fileType = v;
                            _applyFilters();
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'all', child: Text('All types')),
                            PopupMenuItem(value: 'pdf', child: Text('PDF')),
                            PopupMenuItem(value: 'jpg', child: Text('JPG')),
                            PopupMenuItem(value: 'png', child: Text('PNG')),
                            PopupMenuItem(value: 'xlsx', child: Text('Excel')),
                          ],
                          child: _pill('Type: $_fileType'),
                        ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          onSelected: (v) => setState(() {
                            _sort = v;
                            _applyFilters();
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'date', child: Text('Sort by date')),
                            PopupMenuItem(
                                value: 'name', child: Text('Sort by name')),
                            PopupMenuItem(
                                value: 'size', child: Text('Sort by size')),
                          ],
                          child: _pill('Sort: $_sort'),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _cleanupStorage,
                          icon: const Icon(Iconsax.broom, color: Colors.white),
                        ),
                      ],
                    ),
                    if (_bulk) _bulkBar(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _grid ? _buildGrid(grouped) : _buildList(grouped),
          ),
        ],
      ),
    );
  }

  Widget _bulkBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _action('Share', _shareSelected),
          _action('Watermark All', _watermarkSelected),
          _action('ZIP', _zipSelected),
          _action('Merge PDF', _mergePdfSelected),
          _action('Delete', _deleteSelected),
          _action('Tag:Private', () => _tagSelected('private')),
          _action('Tag:Work', () => _tagSelected('Work')),
        ],
      ),
    );
  }

  Widget _buildGrid(Map<DateTime, List<DocumentModel>> grouped) {
    final flat = grouped.values.expand((e) => e).toList();
    if (flat.isEmpty) return _empty();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: flat.length,
      itemBuilder: (_, i) => _card(flat[i]),
    );
  }

  Widget _buildList(Map<DateTime, List<DocumentModel>> grouped) {
    if (grouped.isEmpty) return _empty();
    final keys = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        final docs = grouped[k]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 6),
              child: Text(DateFormat('EEE, dd MMM yyyy').format(k),
                  style: GoogleFonts.nunito(
                      color: AppColors.textMuted, fontWeight: FontWeight.w800)),
            ),
            ...docs.map(_rowTile),
          ],
        );
      },
    );
  }

  Widget _rowTile(DocumentModel d) {
    final selected = d.id != null && _selected.contains(d.id);
    return ListTile(
      onTap: () => _bulk ? _toggleSelect(d) : _open(d),
      leading: _thumb(d),
      title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${SmartGalleryService.instance.categoryFor(d)} • ${d.fileType.toUpperCase()} • ${d.fileSizeMB.toStringAsFixed(1)}MB'),
      trailing: _bulk
          ? Checkbox(value: selected, onChanged: (_) => _toggleSelect(d))
          : IconButton(
              onPressed: () => _toggleFavorite(d),
              icon: Icon(d.isFavorite ? Iconsax.heart5 : Iconsax.heart),
            ),
    );
  }

  Widget _card(DocumentModel d) {
    final selected = d.id != null && _selected.contains(d.id);
    return GestureDetector(
      onTap: () => _bulk ? _toggleSelect(d) : _open(d),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.gold : Colors.black12,
              width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: _thumb(d, fit: BoxFit.cover, full: true))),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  Text(
                    '${d.fileType.toUpperCase()} • ${d.pageCount}p',
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(DocumentModel d,
      {BoxFit fit = BoxFit.cover, bool full = false}) {
    final file = d.thumbnailPath != null && File(d.thumbnailPath!).existsSync()
        ? File(d.thumbnailPath!)
        : null;
    if (file == null) {
      return Container(
        width: full ? double.infinity : 44,
        height: full ? double.infinity : 44,
        color: AppColors.navyMid.withValues(alpha: 0.12),
        child: const Icon(Iconsax.document_text),
      );
    }
    return Image.file(file,
        fit: fit,
        width: full ? double.infinity : 44,
        height: full ? double.infinity : 44);
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

  void _open(DocumentModel d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: d)),
    );
    _load();
  }

  Widget _empty() => Center(
        child: Text('No items',
            style: GoogleFonts.nunito(color: AppColors.textMuted)),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(text,
            style: GoogleFonts.nunito(color: Colors.white70, fontSize: 11)),
      );

  Widget _action(String label, Future<void> Function() onTap) => OutlinedButton(
        onPressed: _selected.isEmpty ? null : onTap,
        child: Text(label),
      );
}
