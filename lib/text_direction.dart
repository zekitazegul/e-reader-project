import 'package:flutter/widgets.dart';

final _leftToRightLetter = RegExp(
  r'[A-Za-z\u00c0-\u024f\u0370-\u058f\u0900-\u1fff\u2e80-\ud7af\uf900-\ufaff]',
);

/// Follow the first letter so mixed-language titles retain their own direction.
TextDirection directionForText(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x05d0 && rune <= 0x05f4) ||
        (rune >= 0x0621 && rune <= 0x064a) ||
        (rune >= 0x0671 && rune <= 0x06d3) ||
        (rune >= 0xfb50 && rune <= 0xfdff) ||
        (rune >= 0xfe70 && rune <= 0xfefc)) {
      return TextDirection.rtl;
    }
    if (_leftToRightLetter.hasMatch(String.fromCharCode(rune))) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.ltr;
}
