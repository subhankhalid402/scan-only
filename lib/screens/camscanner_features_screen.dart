import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../theme.dart';
import 'scan_screen.dart';
import 'text_extraction_screen.dart';
import 'id_photo_maker_screen.dart';
import 'import_documents_screen.dart';
import 'document_conversion_screen.dart';
import 'signature_pad_screen.dart';

class CamScannerFeaturesScreen extends StatelessWidget {
  const CamScannerFeaturesScreen({super.key});

  void _handleFeatureTap(BuildContext context, int index, String title) {
    switch (index) {
      case 0: // Document Scanning
        Navigator.pop(context);
        break;
      case 1: // Auto Crop
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto Crop is available in Edit mode')),
        );
        break;
      case 2: // Filters & Effects
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filters are available in Edit mode')),
        );
        break;
      case 3: // OCR Text Recognition
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a document to extract text')),
        );
        break;
      case 4: // PDF Creation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF creation available when saving documents')),
        );
        break;
      case 5: // Share & Export
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share available in Document Viewer')),
        );
        break;
      case 6: // Annotation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annotation available in Edit mode')),
        );
        break;
      case 7: // Watermark
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watermark available in Edit mode')),
        );
        break;
      case 8: // Timestamp
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timestamp available in Edit mode')),
        );
        break;
      case 9: // Smart Erase
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Smart Erase available in Edit mode')),
        );
        break;
      case 10: // Digital Signature
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SignaturePadScreen()),
        );
        break;
      case 11: // ID Photo Maker
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IdPhotoMakerScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      {
        'icon': Iconsax.camera,
        'title': 'Document Scanning',
        'subtitle': 'Capture documents with camera',
        'color': AppColors.gold,
      },
      {
        'icon': Iconsax.crop,
        'title': 'Auto Crop',
        'subtitle': 'Automatic document edge detection',
        'color': AppColors.blue,
      },
      {
        'icon': Iconsax.setting_2,
        'title': 'Filters & Effects',
        'subtitle': 'Vivid, Cool, Warm, Sepia, B&W',
        'color': AppColors.purple,
      },
      {
        'icon': Iconsax.text,
        'title': 'OCR Text Recognition',
        'subtitle': 'Extract text from documents',
        'color': AppColors.green,
      },
      {
        'icon': Iconsax.document,
        'title': 'PDF Creation',
        'subtitle': 'Convert scans to PDF',
        'color': AppColors.red,
      },
      {
        'icon': Iconsax.share,
        'title': 'Share & Export',
        'subtitle': 'Share via email, cloud, etc',
        'color': AppColors.navyMid,
      },
      {
        'icon': Iconsax.pen_add,
        'title': 'Annotation',
        'subtitle': 'Draw and mark documents',
        'color': AppColors.orange,
      },
      {
        'icon': Iconsax.shield_tick,
        'title': 'Watermark',
        'subtitle': 'Add text/image watermarks',
        'color': AppColors.blue,
      },
      {
        'icon': Iconsax.clock,
        'title': 'Timestamp',
        'subtitle': 'Add date/time to documents',
        'color': AppColors.gold,
      },
      {
        'icon': Iconsax.eraser,
        'title': 'Smart Erase',
        'subtitle': 'Remove unwanted objects',
        'color': AppColors.red,
      },
      {
        'icon': Iconsax.pen_add,
        'title': 'Digital Signature',
        'subtitle': 'Add signatures to documents',
        'color': AppColors.purple,
      },
      {
        'icon': Iconsax.camera,
        'title': 'ID Photo Maker',
        'subtitle': 'Create ID photos',
        'color': AppColors.green,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text(
          'All Features',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: features.length,
        itemBuilder: (_, i) {
          final feature = features[i];
          return GestureDetector(
            onTap: () => _handleFeatureTap(context, i, feature['title'] as String),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (feature['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: feature['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feature['title'] as String,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      feature['subtitle'] as String,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
