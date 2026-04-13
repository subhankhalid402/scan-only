import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../models/document_model.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import 'document_viewer_screen.dart';

/// Pick multiple saved PDFs and merge into one new document.
class MergePdfsScreen extends StatefulWidget {
  const MergePdfsScreen({super.key});

  @override
  State<MergePdfsScreen> createState() => _MergePdfsScreenState();
}

class _MergePdfsScreenState extends State<MergePdfsScreen> {
  List<DocumentModel> _pdfs = [];
  final Set<int> _selectedIds = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseService.instance.getAllDocuments();
    if (!mounted) return;
    setState(() {
      _pdfs = all.where((d) => d.fileType == 'pdf').toList();
      _selectedIds.clear();
    });
  }

  Future<void> _merge() async {
    if (_selectedIds.length < 2) {
      _toast('Select at least two PDFs', isError: true);
      return;
    }
    final ordered = _pdfs.where((d) => _selectedIds.contains(d.id)).toList();
    if (ordered.length < 2) {
      _toast('Select at least two PDFs', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final paths = ordered.map((d) => d.filePath).toList();
      final name = 'Merged_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      final outPath = await PdfService.instance.mergePdfFiles(paths, name);
      final sizeMb = await PdfService.instance.getFileSizeMB(outPath);

      final doc = DocumentModel(
        name: p.basename(outPath),
        filePath: outPath,
        fileType: 'pdf',
        scanType: 'merged',
        pageCount: ordered.fold<int>(0, (a, b) => a + b.pageCount),
        fileSizeMB: sizeMb,
        createdAt: DateTime.now(),
        thumbnailPath: null,
      );
      await DatabaseService.instance.insertDocument(doc);
      if (!mounted) return;
      _toast('Merged successfully');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc)),
      );
      _load();
    } catch (e) {
      if (mounted) _toast('Merge failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        title: Text(
          'Merge PDFs',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: _pdfs.length >= 2
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _merge,
              backgroundColor: AppColors.gold,
              icon: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.navyDark,
                      ),
                    )
                  : const Icon(Iconsax.document_copy, color: AppColors.navyDark),
              label: Text(
                'Merge (${_selectedIds.length})',
                style: GoogleFonts.nunito(
                  color: AppColors.navyDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      body: _pdfs.isEmpty
          ? Center(
              child: Text(
                'No PDFs in library.\nScan or import PDFs first.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pdfs.length,
              itemBuilder: (_, i) {
                final d = _pdfs[i];
                final id = d.id;
                final selected = id != null && _selectedIds.contains(id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected ? AppColors.gold : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: id == null
                        ? null
                        : (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                    secondary: const Icon(Iconsax.document, color: AppColors.red),
                    title: Text(
                      d.name,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${d.pageCount} pages · ${d.fileSizeMB.toStringAsFixed(1)} MB',
                      style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
