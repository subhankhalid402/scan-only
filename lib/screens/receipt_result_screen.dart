import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';
import '../models/receipt_data.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_service.dart';
import '../services/receipt_expense_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/share_file_service.dart';
import '../theme.dart';

class ReceiptResultScreen extends StatefulWidget {
  final List<String> imagePaths;

  const ReceiptResultScreen({super.key, required this.imagePaths});

  @override
  State<ReceiptResultScreen> createState() => _ReceiptResultScreenState();
}

class _ReceiptResultScreenState extends State<ReceiptResultScreen> {
  bool _loading = true;
  bool _busy = false;
  ReceiptData _data = const ReceiptData();
  List<Rect> _textBoxes = const [];
  List<Rect> _itemBoxes = const [];
  Rect? _headerZone;
  Rect? _summaryZone;
  String? _processedImage;
  double _iw = 1;
  double _ih = 1;

  final _store = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _dateTime = TextEditingController();
  final _cashier = TextEditingController();
  final _counter = TextEditingController();
  final _receiptNo = TextEditingController();
  final _ntn = TextEditingController();
  final _gst = TextEditingController();
  final _subtotal = TextEditingController();
  final _discount = TextEditingController();
  final _tax = TextEditingController();
  final _service = TextEditingController();
  final _total = TextEditingController();
  final _payment = TextEditingController();
  final _paid = TextEditingController();
  final _change = TextEditingController();
  final _category = TextEditingController();
  final _currency = TextEditingController();

  List<ReceiptItem> _items = [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    for (final c in [
      _store,
      _address,
      _phone,
      _dateTime,
      _cashier,
      _counter,
      _receiptNo,
      _ntn,
      _gst,
      _subtotal,
      _discount,
      _tax,
      _service,
      _total,
      _payment,
      _paid,
      _change,
      _category,
      _currency,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final stitched = await ReceiptOcrService.instance.stitchLongReceipt(widget.imagePaths);
      final enhanced = await ReceiptOcrService.instance.enhanceReceiptImage(stitched);
      _processedImage = enhanced;
      final res = await ReceiptOcrService.instance.extract(enhanced);
      final dup = await ReceiptExpenseService.instance.isDuplicate(res.data);
      _data = res.data.copyWith(isDuplicate: dup);
      _textBoxes = res.textBoxes;
      _itemBoxes = res.itemBoxes;
      _headerZone = res.headerZone;
      _summaryZone = res.summaryZone;
      _items = List<ReceiptItem>.from(_data.items);
      _fillFields(_data);
      await _measureImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Receipt extraction failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _measureImage() async {
    final path = _processedImage;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    if (!mounted) return;
    setState(() {
      _iw = decoded.width.toDouble();
      _ih = decoded.height.toDouble();
    });
  }

  void _fillFields(ReceiptData d) {
    _store.text = d.storeName;
    _address.text = d.storeAddress;
    _phone.text = d.contactNumber;
    _dateTime.text = d.purchaseDateTime;
    _cashier.text = d.cashierName;
    _counter.text = d.counterNumber;
    _receiptNo.text = d.receiptNumber;
    _ntn.text = d.ntnNumber;
    _gst.text = d.gstNumber;
    _subtotal.text = d.subtotal;
    _discount.text = d.discount;
    _tax.text = d.tax;
    _service.text = d.serviceCharge;
    _total.text = d.grandTotal;
    _payment.text = d.paymentMethod;
    _paid.text = d.amountPaid;
    _change.text = d.changeReturned;
    _category.text = d.category;
    _currency.text = d.currency;
  }

  ReceiptData _currentData() {
    return _data.copyWith(
      storeName: _store.text.trim(),
      storeAddress: _address.text.trim(),
      contactNumber: _phone.text.trim(),
      purchaseDateTime: _dateTime.text.trim(),
      cashierName: _cashier.text.trim(),
      counterNumber: _counter.text.trim(),
      receiptNumber: _receiptNo.text.trim(),
      ntnNumber: _ntn.text.trim(),
      gstNumber: _gst.text.trim(),
      subtotal: _subtotal.text.trim(),
      discount: _discount.text.trim(),
      tax: _tax.text.trim(),
      serviceCharge: _service.text.trim(),
      grandTotal: _total.text.trim(),
      paymentMethod: _payment.text.trim(),
      amountPaid: _paid.text.trim(),
      changeReturned: _change.text.trim(),
      category: _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
      currency: _currency.text.trim().isEmpty ? 'PKR' : _currency.text.trim(),
      items: List<ReceiptItem>.from(_items),
    );
  }

  Future<String> _saveJson(ReceiptData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/Receipts');
    await outDir.create(recursive: true);
    final out = File('${outDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.json');
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(d.toJsonMap()));
    return out.path;
  }

  Future<void> _exportAll() async {
    if (_busy || _processedImage == null) return;
    setState(() => _busy = true);
    try {
      final d = _currentData();
      final base = d.storeName.isEmpty ? 'Receipt' : d.storeName.replaceAll(' ', '_');
      final pdfPath = await PdfService.instance.createPdfFromImages([_processedImage!], base);
      final thumb = await PdfService.instance.generateThumbnail(_processedImage!);
      final size = await PdfService.instance.getFileSizeMB(pdfPath);
      await DatabaseService.instance.insertDocument(
        DocumentModel(
          name: '$base.pdf',
          filePath: pdfPath,
          fileType: 'pdf',
          scanType: 'receipt',
          pageCount: 1,
          fileSizeMB: size,
          createdAt: DateTime.now(),
          thumbnailPath: thumb,
          ocrText: d.rawText,
          tags: [d.category, 'Receipt'],
        ),
      );

      await ReceiptExpenseService.instance.saveExpense(d);
      final jsonPath = await _saveJson(d);
      final excelPath = await ExcelExportService.instance.exportReceiptsToExcel([d.toJsonMap()]);
      final csvPath = await _saveCsv(d);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported PDF, JSON, Excel, CSV', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.green,
        ),
      );
      await ShareFileService.sharePaths(
        [pdfPath, jsonPath, excelPath, csvPath],
        text: 'Receipt export (${d.storeName})',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _saveCsv(ReceiptData d) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/ScanOnly/Receipts');
    await outDir.create(recursive: true);
    final out = File('${outDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.csv');
    final rows = <String>[
      'store,datetime,category,currency,grand_total,payment,receipt_no,ntn,gst,fbr_qr_valid',
      '"${d.storeName}","${d.purchaseDateTime}","${d.category}","${d.currency}","${d.grandTotal}","${d.paymentMethod}","${d.receiptNumber}","${d.ntnNumber}","${d.gstNumber}","${d.fbrQrValid}"',
      '',
      'item,qty,unit_price,total_price',
      ...d.items.map((i) => '"${i.name}","${i.qty}","${i.unitPrice}","${i.totalPrice}"'),
    ];
    await out.writeAsString(rows.join('\n'));
    return out.path;
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final d = _currentData();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111824),
        title: Text('Receipt Intelligence', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _previewCard(d),
                  const SizedBox(height: 10),
                  _analyticsCard(),
                  const SizedBox(height: 10),
                  _section('Header', const Color(0xFF1D3D7C), [
                    _field('Store Name', _store),
                    _field('Address', _address, maxLines: 2),
                    _field('Contact', _phone),
                    _field('Date & Time', _dateTime),
                    _field('Cashier', _cashier),
                    _field('Counter', _counter),
                    _field('Receipt/Invoice No', _receiptNo),
                    _field('NTN', _ntn),
                    _field('GST', _gst),
                  ]),
                  const SizedBox(height: 8),
                  _itemsSection(),
                  const SizedBox(height: 8),
                  _section('Summary', const Color(0xFF0E5B45), [
                    _field('Subtotal', _subtotal),
                    _field('Discount', _discount),
                    _field('Tax/GST/VAT', _tax),
                    _field('Service Charge', _service),
                    _field('Grand Total', _total),
                    _field('Payment Method', _payment),
                    _field('Amount Paid', _paid),
                    _field('Change Returned', _change),
                    _field('Category', _category),
                    _field('Currency', _currency),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _saveJson(_currentData()),
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text('JSON'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navyDark,
                          ),
                          onPressed: _busy ? null : _exportAll,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Export + Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _previewCard(ReceiptData d) {
    final imagePath = _processedImage;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.storeName.isEmpty ? 'Receipt Preview' : d.storeName,
                  style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: d.fbrQrValid ? AppColors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  d.fbrQrValid ? 'FBR Valid' : 'FBR Unverified',
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (imagePath != null)
            AspectRatio(
              aspectRatio: _iw / _ih,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(imagePath), fit: BoxFit.cover),
                  CustomPaint(
                    painter: _ReceiptOverlayPainter(
                      iw: _iw,
                      ih: _ih,
                      textBoxes: _textBoxes,
                      headerZone: _headerZone,
                      summaryZone: _summaryZone,
                      itemBoxes: _itemBoxes,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${d.currency} ${d.grandTotal.isEmpty ? '0' : d.grandTotal}',
            style: GoogleFonts.nunito(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard() {
    return FutureBuilder<Map<String, double>>(
      future: ReceiptExpenseService.instance.monthlySpendingSummary(),
      builder: (context, snap) {
        final map = snap.data ?? const <String, double>{};
        final total = map.values.fold<double>(0, (a, b) => a + b);
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF131F34),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly Spending Summary', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Total: ${total.toStringAsFixed(2)}', style: GoogleFonts.nunito(color: AppColors.gold, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ...map.entries.map((e) {
                final ratio = total <= 0 ? 0.0 : (e.value / total).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key}: ${e.value.toStringAsFixed(2)}', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String title, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.nunito(color: color, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _itemsSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF162232),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBF8A00)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Items', style: GoogleFonts.nunito(color: const Color(0xFFEEB341), fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _items.add(const ReceiptItem())),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _inline('Item', item.name, (v) => _items[i] = _items[i].copyWith(name: v)),
                  _inline('Qty', item.qty, (v) => _items[i] = _items[i].copyWith(qty: v)),
                  _inline('Unit', item.unitPrice, (v) => _items[i] = _items[i].copyWith(unitPrice: v)),
                  _inline('Total', item.totalPrice, (v) => _items[i] = _items[i].copyWith(totalPrice: v)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _inline(String label, String value, ValueChanged<String> onChanged) {
    final ctrl = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(label, style: ScanResultFormStyle.labelOnDarkPanel())),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: (v) => setState(() => onChanged(v)),
              style: ScanResultFormStyle.inputText(fontSize: 13),
              decoration: ScanResultFormStyle.textFieldOnDarkPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: ScanResultFormStyle.labelOnDarkPanel(fontSize: 12))),
              IconButton(
                onPressed: () => _copy(label, ctrl.text.trim()),
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: AppColors.gold,
              ),
            ],
          ),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            style: ScanResultFormStyle.inputText(fontSize: 13),
            decoration: ScanResultFormStyle.textFieldOnDarkPanel(),
          ),
        ],
      ),
    );
  }
}

class _ReceiptOverlayPainter extends CustomPainter {
  final double iw;
  final double ih;
  final List<Rect> textBoxes;
  final Rect? headerZone;
  final Rect? summaryZone;
  final List<Rect> itemBoxes;

  const _ReceiptOverlayPainter({
    required this.iw,
    required this.ih,
    required this.textBoxes,
    required this.headerZone,
    required this.summaryZone,
    required this.itemBoxes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (iw <= 1 || ih <= 1) return;
    final sx = size.width / iw;
    final sy = size.height / ih;
    Rect tr(Rect r) => Rect.fromLTRB(r.left * sx, r.top * sy, r.right * sx, r.bottom * sy);

    if (headerZone != null) {
      canvas.drawRect(tr(headerZone!), Paint()..color = const Color(0xFF1D3D7C).withValues(alpha: 0.18));
    }
    if (summaryZone != null) {
      canvas.drawRect(tr(summaryZone!), Paint()..color = const Color(0xFF0E5B45).withValues(alpha: 0.18));
    }
    final tPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.25);
    for (final b in textBoxes) {
      canvas.drawRect(tr(b), tPaint);
    }
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFEEB341);
    for (final b in itemBoxes) {
      canvas.drawRect(tr(b), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptOverlayPainter oldDelegate) =>
      oldDelegate.iw != iw ||
      oldDelegate.ih != ih ||
      oldDelegate.textBoxes != textBoxes ||
      oldDelegate.headerZone != headerZone ||
      oldDelegate.summaryZone != summaryZone ||
      oldDelegate.itemBoxes != itemBoxes;
}

