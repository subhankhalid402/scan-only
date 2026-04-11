import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();

  factory TranslationService() {
    return _instance;
  }

  TranslationService._internal();

  static TranslationService get instance => _instance;

  final Map<String, Translator> _translators = {};

  Future<Translator> _getTranslator(String sourceLanguage, String targetLanguage) async {
    final key = '$sourceLanguage-$targetLanguage';
    if (!_translators.containsKey(key)) {
      _translators[key] = Translator(
        sourceLanguage: TranslateLanguage.byCode(sourceLanguage)!,
        targetLanguage: TranslateLanguage.byCode(targetLanguage)!,
      );
    }
    return _translators[key]!;
  }

  Future<String> translateText(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    try {
      final translator = await _getTranslator(sourceLanguage, targetLanguage);
      final translatedText = await translator.translateText(text);
      return translatedText;
    } catch (e) {
      return text;
    }
  }

  void dispose() {
    for (var translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
  }
}
