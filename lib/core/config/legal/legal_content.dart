import 'dart:ui';

import 'legal_content_en.dart';

export 'legal_content_en.dart';

/// Textos legales por idioma con fallback a inglés.
///
/// La app está localizada a 4 idiomas pero los documentos legales solo
/// existen en inglés por ahora. Cuando haya traducciones revisadas, crear
/// `legal_content_es.dart` (etc.) y añadir la entrada al mapa — los textos
/// legales NO van en los .arb (los strings multilínea largos los degradan).
typedef LegalContent = ({String privacyPolicy, String termsOfService});

const LegalContent _en = (
  privacyPolicy: privacyPolicyContentEn,
  termsOfService: termsOfServiceContentEn,
);

const Map<String, LegalContent> _byLanguageCode = {
  'en': _en,
  // 'es': _es,  ← pendiente de traducción revisada (legal_content_es.dart)
  // 'fr': _fr,
  // 'de': _de,
};

/// Devuelve el contenido legal para [locale], con fallback a inglés.
LegalContent legalContentFor(Locale locale) =>
    _byLanguageCode[locale.languageCode] ?? _en;
