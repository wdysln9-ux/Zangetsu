import 'package:flutter/material.dart';

import '../metadata/synopsis_translator.dart';
import '../theme/app_colors.dart';

/// Shows Indonesian text when available while showing the Indonesian translation without an original-text toggle.
/// Translation is best-effort; the original remains visible if it fails.
class AutoTranslatedText extends StatefulWidget {
  const AutoTranslatedText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.showToggle = false,
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
  bool _showOriginal = false;

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
      _showOriginal = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _translation,
      builder: (context, snapshot) {
        final translated = snapshot.data;
        final hasTranslation = translated != null && translated.isNotEmpty;
        final shown = hasTranslation && !_showOriginal ? translated : widget.text;
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
            if (hasTranslation && widget.showToggle)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showOriginal = !_showOriginal),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 1, right: 6),
                    child: Text(
                      _showOriginal ? 'Terjemahan' : 'Asli',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
