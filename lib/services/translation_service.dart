import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// On-device translation via ML Kit ([OnDeviceTranslator]).
/// Native code downloads language models on first use.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static TranslateLanguage _guessSourceLanguage(String text) {
    var arabic = 0, latin = 0, deva = 0, cjk = 0;
    for (final r in text.runes) {
      if (r >= 0x0600 && r <= 0x06FF) {
        arabic++;
      } else if ((r >= 0x0041 && r <= 0x005A) ||
          (r >= 0x0061 && r <= 0x007A)) {
        latin++;
      } else if (r >= 0x0900 && r <= 0x097F) {
        deva++;
      } else if (r >= 0x4E00 && r <= 0x9FFF) {
        cjk++;
      }
    }
    if (deva > 0 && deva >= latin && deva >= arabic) {
      return TranslateLanguage.hindi;
    }
    if (cjk > 4 && cjk >= latin) {
      return TranslateLanguage.chinese;
    }
    if (arabic > 0 && arabic >= latin) {
      return TranslateLanguage.urdu;
    }
    return TranslateLanguage.english;
  }

  static TranslateLanguage? _targetFromDisplayName(String name) {
    switch (name) {
      case 'Urdu':
        return TranslateLanguage.urdu;
      case 'English':
        return TranslateLanguage.english;
      case 'Arabic':
        return TranslateLanguage.arabic;
      case 'French':
        return TranslateLanguage.french;
      case 'German':
        return TranslateLanguage.german;
      case 'Spanish':
        return TranslateLanguage.spanish;
      case 'Chinese':
        return TranslateLanguage.chinese;
      case 'Hindi':
        return TranslateLanguage.hindi;
      default:
        return null;
    }
  }

  /// Translates [text] to the language selected in the OCR UI (display name).
  Future<String> translateToNamedLanguage(
    String text,
    String targetDisplayName,
  ) async {
    final target = _targetFromDisplayName(targetDisplayName);
    if (target == null) {
      throw ArgumentError.value(
        targetDisplayName,
        'targetDisplayName',
        'Unsupported target language',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final source = _guessSourceLanguage(trimmed);
    if (source == target) {
      return trimmed;
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      return await translator.translateText(trimmed);
    } finally {
      await translator.close();
    }
  }
}
