class WhiteboardZone {
  final String type; // text | diagram | table | equation
  final String snippet;

  const WhiteboardZone({required this.type, required this.snippet});

  Map<String, dynamic> toJson() => {
        'type': type,
        'snippet': snippet,
      };
}

class WhiteboardScanData {
  final String text;
  final String handwritingText;
  final String urduText;
  final bool hasEquation;
  final bool hasFlowchart;
  final bool hasDrawnTable;
  final bool hasArrows;
  final bool rtlDetected;
  final bool mixedLanguage;
  final bool glareReduced;
  final bool backgroundWhitened;
  final bool perspectiveCorrected;
  final bool stitchedMultiShot;
  final List<String> latexEquations;
  final List<WhiteboardZone> zones;
  final String cleanedImagePath;

  const WhiteboardScanData({
    this.text = '',
    this.handwritingText = '',
    this.urduText = '',
    this.hasEquation = false,
    this.hasFlowchart = false,
    this.hasDrawnTable = false,
    this.hasArrows = false,
    this.rtlDetected = false,
    this.mixedLanguage = false,
    this.glareReduced = false,
    this.backgroundWhitened = false,
    this.perspectiveCorrected = false,
    this.stitchedMultiShot = false,
    this.latexEquations = const [],
    this.zones = const [],
    this.cleanedImagePath = '',
  });

  Map<String, dynamic> toJsonMap() => {
        'text': text,
        'handwriting_text': handwritingText,
        'urdu_text': urduText,
        'has_equation': hasEquation,
        'has_flowchart': hasFlowchart,
        'has_drawn_table': hasDrawnTable,
        'has_arrows': hasArrows,
        'rtl_detected': rtlDetected,
        'mixed_language': mixedLanguage,
        'glare_reduced': glareReduced,
        'background_whitened': backgroundWhitened,
        'perspective_corrected': perspectiveCorrected,
        'stitched_multi_shot': stitchedMultiShot,
        'latex_equations': latexEquations,
        'zones': zones.map((e) => e.toJson()).toList(),
        'cleaned_image_path': cleanedImagePath,
      };
}

