import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:markdown/markdown.dart' as md;

import '../theme/app_colors.dart';

/// Renders AniList-flavoured Markdown. Kept as a dedicated widget so only
/// AniList-authored bios and synopses opt into this renderer.
class AniListMarkdown extends StatelessWidget {
  const AniListMarkdown({
    super.key,
    required this.data,
    this.textStyle,
  });

  final String data;
  final TextStyle? textStyle;

  String _toHtml(String source) {
    // AniList treats single newlines as visible line breaks.
    final withBreaks = source.replaceAllMapped(
      RegExp(r'(?<!\n)\n(?!\n)'),
      (_) => '  \n',
    );

    var html = md.markdownToHtml(
      withBreaks,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    // AniList's spoiler delimiters are not part of CommonMark.
    html = html.replaceAllMapped(
      RegExp(r'~!(.*?)!~', dotAll: true),
      (match) => '<span class="anilist-spoiler">${match[1] ?? ''}</span>',
    );

    // AniList's image-size shorthand: img420(https://...)
    html = html.replaceAllMapped(
      RegExp(r'img(\\d{1,4})\\((https?://[^)]+)\\)'),
      (match) =>
          '<img src="${match[2]}" width="${match[1]}" />',
    );

    // Center alignment shorthand used by AniList profiles.
    html = html.replaceAll('˜˜˜', '<div class="anilist-center">');
    return html;
  }

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? Theme.of(context).textTheme.bodyMedium;
    return HtmlWidget(
      _toHtml(data),
      textStyle: base,
      renderMode: RenderMode.column,
      onTapUrl: (url) async {
        // Let the host handle external navigation where available.
        return false;
      },
      customStylesBuilder: (element) {
        switch (element.localName) {
          case 'p':
            return {'margin': '0 0 10px 0', 'line-height': '1.45'};
          case 'blockquote':
            return {
              'font-style': 'italic',
              'color': '#B0B0B0',
              'border-left': '3px solid #777777',
              'padding-left': '10px',
            };
          case 'pre':
          case 'code':
            return {
              'font-family': 'monospace',
              'background-color': '#242424',
            };
          case 'a':
            return {'color': '#F47521'};
          case 'img':
            return {'max-width': '100%'};
          case 'div':
            if (element.classes.contains('anilist-center')) {
              return {'text-align': 'center'};
            }
            break;
        }
        return null;
      },
      customWidgetBuilder: (element) {
        if (!element.classes.contains('anilist-spoiler')) return null;
        var revealed = false;
        return StatefulBuilder(
          builder: (context, setState) => GestureDetector(
            onTap: () => setState(() => revealed = !revealed),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: revealed ? AppColors.surface2 : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: revealed
                  ? HtmlWidget(element.innerHtml, textStyle: base)
                  : Text(
                      'Spoiler — ketuk untuk melihat',
                      style: (base ?? const TextStyle()).copyWith(
                        color: AppColors.bg,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
