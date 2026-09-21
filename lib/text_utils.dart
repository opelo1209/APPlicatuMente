import 'package:flutter/material.dart';

/// Devuelve un [TextSpan] con PHQ-9, C-SSRS y NSSI en cursiva.
TextSpan italicAcronyms(String text, TextStyle base) {
  final pattern = RegExp(r'(PHQ-9|C-SSRS|NSSI)');
  final spans = <InlineSpan>[];
  int last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: const TextStyle(fontStyle: FontStyle.italic),
    ));
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return TextSpan(style: base, children: spans);
}
