import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';
import '../metadata/synopsis_translator.dart';

/// Renders Markdown-rich descriptions, including AniList formatting, images,
/// spoilers and inline YouTube embeds.
class AniListMarkdown extends StatelessWidget {
  const AniListMarkdown({
    super.key,
    required this.data,
    this.textStyle,
  });

  final String data;
  final TextStyle? textStyle;

  String _toHtml(String source) {
    // Parse AniList center blocks separately so nested Markdown survives.
    final centerBlocks = <String>[];
    final prepared = source.replaceAllMapped(
      RegExp(r'˜˜˜([\s\S]*?)˜˜˜', dotAll: true),
      (match) {
        final index = centerBlocks.length;
        centerBlocks.add(match[1] ?? '');
        return '\n\nANILIST_CENTER_BLOCK_${index}_PLACEHOLDER\n\n';
      },
    );

    // AniList treats single newlines as visible line breaks.
    final withBreaks = prepared.replaceAllMapped(
      RegExp(r'(?<!\n)\n(?!\n)'),
      (_) => '  \n',
    );

    var html = md.markdownToHtml(
      withBreaks,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    html = html.replaceAllMapped(
      RegExp(r'~!(.*?)!~', dotAll: true),
      (match) => '<span class="anilist-spoiler">${match[1] ?? ''}</span>',
    );

    // AniList image-size shorthand: img420(https://...)
    html = html.replaceAllMapped(
      RegExp(r'img(\d{1,4})\((https?://[^)]+)\)'),
      (match) => '<img src="${match[2]}" width="${match[1]}" />',
    );

    html = html.replaceAllMapped(
      RegExp(r'youtube\(([^)]+)\)'),
      (match) {
        final value = match[1]!.trim();
        final uri = Uri.tryParse(
          value.startsWith('http') ? value : 'https://youtu.be/$value',
        );
        String? id;
        if (uri != null) {
          if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
            id = uri.pathSegments.first;
          } else {
            id = uri.queryParameters['v'];
            final embedIndex = uri.pathSegments.indexOf('embed');
            if ((id == null || id.isEmpty) &&
                embedIndex >= 0 &&
                embedIndex + 1 < uri.pathSegments.length) {
              id = uri.pathSegments[embedIndex + 1];
            }
          }
        }
        if (id == null || id.isEmpty) return match[0]!;
        return '<iframe src="https://www.youtube.com/embed/$id" '
            'width="560" height="315"></iframe>';
      },
    );
    html = html.replaceAllMapped(
      RegExp(r'webm\((https?://[^)]+)\)'),
      (match) =>
          '<video src="${match[1]}" controls loop muted autoplay></video>',
    );

    html = html.replaceAllMapped(
      RegExp(r"""<div\s+rel=["']spoiler["']>(.*?)</div>""", dotAll: true),
      (match) =>
          '<span class="anilist-spoiler">${match[1] ?? ''}</span>',
    );

    // Render Markdown inside each center block before inserting its HTML.
    for (var i = 0; i < centerBlocks.length; i++) {
      final inner = centerBlocks[i].replaceAllMapped(
        RegExp(r'(?<!\n)\n(?!\n)'),
        (_) => '  \n',
      );
      final innerHtml = md.markdownToHtml(
        inner,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      );
      final marker = 'ANILIST_CENTER_BLOCK_${i}_PLACEHOLDER';
      final centered = '<div class="anilist-center">$innerHtml</div>';
      html = html.replaceAll('<p>$marker</p>', centered);
      html = html.replaceAll(marker, centered);
    }
    return html;
  }
  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? Theme.of(context).textTheme.bodyMedium;
    final linkColor = '#${(AppColors.accent.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return HtmlWidget(
      _toHtml(data),
      textStyle: base,
      renderMode: RenderMode.column,
      onTapUrl: (url) async {
        // Let the host handle external navigation where available.
        return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
            return {
              'color': linkColor,
              'text-decoration': 'none',
            };
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
        if (element.localName == 'iframe') {
          final src = Uri.tryParse(element.attributes['src'] ?? '');
          final isYoutube = src != null &&
              (src.host == 'www.youtube.com' ||
                  src.host == 'youtube.com' ||
                  src.host == 'www.youtube-nocookie.com' ||
                  src.host == 'youtube-nocookie.com') &&
              src.path.startsWith('/embed/');
          if (!isYoutube) return const SizedBox.shrink();
          return _YoutubeMarkdownEmbed(uri: src);
        }
        if (element.localName == 'img') {
          final src = element.attributes['src'];
          if (src == null || src.isEmpty) return const SizedBox.shrink();
          final width = double.tryParse(element.attributes['width'] ?? '');
          return LayoutBuilder(
            builder: (context, constraints) => Image.network(
              src,
              width: width == null
                  ? constraints.maxWidth
                  : width.clamp(1, constraints.maxWidth).toDouble(),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          );
        }
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

/// AniList bio variant that keeps the existing best-effort Indonesian
/// translation while rendering the translated result as Markdown.
class AutoTranslatedAniListMarkdown extends StatefulWidget {
  const AutoTranslatedAniListMarkdown({
    super.key,
    required this.data,
    this.textStyle,
  });

  final String data;
  final TextStyle? textStyle;

  @override
  State<AutoTranslatedAniListMarkdown> createState() =>
      _AutoTranslatedAniListMarkdownState();
}

class _AutoTranslatedAniListMarkdownState
    extends State<AutoTranslatedAniListMarkdown> {
  String? _translated;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(covariant AutoTranslatedAniListMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _translated = null;
      _translate();
    }
  }

  Future<void> _translate() async {
    final result = await SynopsisTranslator.instance.translateTextToIndonesian(
      widget.data,
    );
    if (!mounted) return;
    setState(() {
      _translated = result != widget.data ? result : null;
    });
  }

  @override
  Widget build(BuildContext context) => AniListMarkdown(
    data: _translated ?? widget.data,
    textStyle: widget.textStyle,
  );
}


/// Inline YouTube player used by Markdown's youtube(...) syntax.
class _YoutubeMarkdownEmbed extends StatefulWidget {
  const _YoutubeMarkdownEmbed({required this.uri});

  final Uri uri;

  @override
  State<_YoutubeMarkdownEmbed> createState() => _YoutubeMarkdownEmbedState();
}

class _YoutubeMarkdownEmbedState extends State<_YoutubeMarkdownEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: WebViewWidget(controller: _controller),
    ),
  );
}
