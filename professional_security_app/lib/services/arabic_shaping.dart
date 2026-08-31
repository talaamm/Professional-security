/// Correct Arabic contextual letter-shaping (isolated/initial/medial/final
/// presentation forms) plus right-to-left glyph reordering, implemented
/// from scratch in pure Dart.
///
/// Why this exists: the `pdf` package (see pubspec.yaml) does its own
/// Arabic shaping internally (its lib/src/pdf/font/bidi_utils.dart, active
/// whenever a pw.Text has textDirection: rtl) but that table maps every
/// occurrence of a letter to one fixed presentation form instead of
/// choosing isolated/initial/medial/final based on its neighbours - every
/// MEEM (U+0645), for example, is always mapped to its isolated form
/// (U+FEE1) regardless of position, which only looks right when a meem
/// genuinely needs isolated form and renders as disconnected loops
/// otherwise. Confirmed this independently of font choice (reproduces
/// identically with two unrelated fonts), so it isn't fixable by picking
/// a different font - it's a bug in that shaping table itself.
///
/// The table below is ported from the well-known Python `arabic_reshaper`
/// library (github.com/mpcabd/python-arabic-reshaper), whose output was
/// used as the known-correct reference while diagnosing this. It covers
/// the 36 standard Arabic letters used in real Arabic words/names
/// (U+0621-U+064A) - Persian/Urdu/Kurdish-only letters are out of scope;
/// any character not in the table passes through unchanged (same as
/// before), so nothing regresses for them.
library;

const int _isolated = 0;
const int _initial = 1;
const int _medial = 2;
const int _final = 3;
const int _notSupported = -1;

/// letter code point -> [isolated, initial, medial, final] presentation
/// form code points. 0 means that letter has no such form.
const Map<int, List<int>> _arabicForms = {
  0x0621: [0xFE80, 0, 0, 0], // HAMZA
  0x0622: [0xFE81, 0, 0, 0xFE82], // ALEF WITH MADDA ABOVE
  0x0623: [0xFE83, 0, 0, 0xFE84], // ALEF WITH HAMZA ABOVE
  0x0624: [0xFE85, 0, 0, 0xFE86], // WAW WITH HAMZA ABOVE
  0x0625: [0xFE87, 0, 0, 0xFE88], // ALEF WITH HAMZA BELOW
  0x0626: [0xFE89, 0xFE8B, 0xFE8C, 0xFE8A], // YEH WITH HAMZA ABOVE
  0x0627: [0xFE8D, 0, 0, 0xFE8E], // ALEF
  0x0628: [0xFE8F, 0xFE91, 0xFE92, 0xFE90], // BEH
  0x0629: [0xFE93, 0, 0, 0xFE94], // TEH MARBUTA
  0x062A: [0xFE95, 0xFE97, 0xFE98, 0xFE96], // TEH
  0x062B: [0xFE99, 0xFE9B, 0xFE9C, 0xFE9A], // THEH
  0x062C: [0xFE9D, 0xFE9F, 0xFEA0, 0xFE9E], // JEEM
  0x062D: [0xFEA1, 0xFEA3, 0xFEA4, 0xFEA2], // HAH
  0x062E: [0xFEA5, 0xFEA7, 0xFEA8, 0xFEA6], // KHAH
  0x062F: [0xFEA9, 0, 0, 0xFEAA], // DAL
  0x0630: [0xFEAB, 0, 0, 0xFEAC], // THAL
  0x0631: [0xFEAD, 0, 0, 0xFEAE], // REH
  0x0632: [0xFEAF, 0, 0, 0xFEB0], // ZAIN
  0x0633: [0xFEB1, 0xFEB3, 0xFEB4, 0xFEB2], // SEEN
  0x0634: [0xFEB5, 0xFEB7, 0xFEB8, 0xFEB6], // SHEEN
  0x0635: [0xFEB9, 0xFEBB, 0xFEBC, 0xFEBA], // SAD
  0x0636: [0xFEBD, 0xFEBF, 0xFEC0, 0xFEBE], // DAD
  0x0637: [0xFEC1, 0xFEC3, 0xFEC4, 0xFEC2], // TAH
  0x0638: [0xFEC5, 0xFEC7, 0xFEC8, 0xFEC6], // ZAH
  0x0639: [0xFEC9, 0xFECB, 0xFECC, 0xFECA], // AIN
  0x063A: [0xFECD, 0xFECF, 0xFED0, 0xFECE], // GHAIN
  0x0640: [0x0640, 0x0640, 0x0640, 0x0640], // TATWEEL
  0x0641: [0xFED1, 0xFED3, 0xFED4, 0xFED2], // FEH
  0x0642: [0xFED5, 0xFED7, 0xFED8, 0xFED6], // QAF
  0x0643: [0xFED9, 0xFEDB, 0xFEDC, 0xFEDA], // KAF
  0x0644: [0xFEDD, 0xFEDF, 0xFEE0, 0xFEDE], // LAM
  0x0645: [0xFEE1, 0xFEE3, 0xFEE4, 0xFEE2], // MEEM
  0x0646: [0xFEE5, 0xFEE7, 0xFEE8, 0xFEE6], // NOON
  0x0647: [0xFEE9, 0xFEEB, 0xFEEC, 0xFEEA], // HEH
  0x0648: [0xFEED, 0, 0, 0xFEEE], // WAW
  0x0649: [0xFEEF, 0xFBE8, 0xFBE9, 0xFEF0], // ALEF MAKSURA
  0x064A: [0xFEF1, 0xFEF3, 0xFEF4, 0xFEF2], // YEH
};

bool _connectsAfter(int letter) {
  final forms = _arabicForms[letter];
  return forms != null && (forms[_initial] != 0 || forms[_medial] != 0);
}

bool _connectsBefore(int letter) {
  final forms = _arabicForms[letter];
  return forms != null && (forms[_final] != 0 || forms[_medial] != 0);
}

bool _connectsBothSides(int letter) {
  final forms = _arabicForms[letter];
  return forms != null && forms[_medial] != 0;
}

/// Whether [text] contains any character in the Arabic Unicode block
/// (U+0600-U+06FF) - the range this shaper knows how to handle.
bool containsArabic(String text) {
  for (final code in text.codeUnits) {
    if (code >= 0x0600 && code <= 0x06FF) return true;
  }
  return false;
}

/// Shapes [text] (choosing each Arabic letter's isolated/initial/medial/
/// final presentation form from its neighbours) and reverses the result
/// for right-to-left visual display. The returned string is meant to be
/// rendered by a plain left-to-right text widget - do not also ask the
/// renderer to apply its own RTL/bidi handling on top of this.
///
/// Characters outside the Arabic letter table (spaces, digits, Latin,
/// punctuation) pass through unchanged at their original position, same
/// as the reference implementation this was checked against.
String shapeArabicForDisplay(String text) {
  final outputLetters = <int>[];
  final outputForms = <int>[];

  for (final letter in text.codeUnits) {
    if (!_arabicForms.containsKey(letter)) {
      outputLetters.add(letter);
      outputForms.add(_notSupported);
      continue;
    }

    if (outputLetters.isEmpty) {
      outputLetters.add(letter);
      outputForms.add(_isolated);
      continue;
    }

    final prevLetter = outputLetters.last;
    final prevForm = outputForms.last;

    if (prevForm == _notSupported ||
        !_connectsBefore(letter) ||
        !_connectsAfter(prevLetter)) {
      outputLetters.add(letter);
      outputForms.add(_isolated);
    } else if (prevForm == _final && !_connectsBothSides(prevLetter)) {
      outputLetters.add(letter);
      outputForms.add(_isolated);
    } else if (prevForm == _isolated) {
      outputForms[outputForms.length - 1] = _initial;
      outputLetters.add(letter);
      outputForms.add(_final);
    } else {
      outputForms[outputForms.length - 1] = _medial;
      outputLetters.add(letter);
      outputForms.add(_final);
    }
  }

  final presentationForms = <int>[
    for (var i = 0; i < outputLetters.length; i++)
      if (outputForms[i] == _notSupported)
        outputLetters[i]
      else
        (_arabicForms[outputLetters[i]]![outputForms[i]] == 0
            ? outputLetters[i]
            : _arabicForms[outputLetters[i]]![outputForms[i]]),
  ];

  return String.fromCharCodes(presentationForms.reversed);
}
