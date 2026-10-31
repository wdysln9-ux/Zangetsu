import 'package:flutter/material.dart';

import '../metadata/synopsis_translator.dart';

/// Shows Indonesian text when available. Translation is best-effort;
/// the source text remains as a fallback if translation fails.
class AutoTranslatedText extends StatefulWidget {
  const AutoTranslatedText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.showToggle = true,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool showToggle;

  @override
  State<AutoTranslatedText> createState() => _AutoTranslatedTextState();
}

class _AutoTranslatedTextState extends State<AutoTranslatedText> {
  late Future<String?> _translation;

  @override
  void initState() {
    super.initState();
    _translation = SynopsisTranslator.instance.translateTextToIndonesian(widget.text);
  }

  @override
  void didUpdateWidget(covariant AutoTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translation = SynopsisTranslator.instance.translateTextToIndonesian(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _translation,
      builder: (context, snapshot) {
        final translated = snapshot.data;
        final hasTranslation = translated != null && translated.isNotEmpty;
        final shown = hasTranslation ? translated : widget.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shown,
              style: widget.style,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              textAlign: widget.textAlign,
            ),
          ],
        );
      },
    );
  }
}
