import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

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
    // AniList users often write ATX headings without the optional space:
    // "##Heading". Normalize those lines before passing them to the Markdown parser.
    source = source.replaceAllMapped(
      RegExp(r'^(#{1,6})(?=\S)', multiLine: true),
      (match) => '${match[1]} ',
    );
    // Protect AniList embeds before Markdown parsing; otherwise URLs in the
    // parentheses are parsed as ordinary Markdown links.
    final embeds = <String, String>{};
    var embedIndex = 0;
    final protectedSource = source.replaceAllMapped(
      RegExp(r'img(?:(\d{1,4})|(\d{1,3})%)?\((https?://[^)\s]+)\)|youtube\(([^)]+)\)|webm\((https?://[^)]+)\)'),
      (match) {
        final token = 'ANILIST_EMBED_${embedIndex++}_TOKEN';
        if (match[3] != null) {
          final pxWidth = match[1];
          final percentWidth = match[2];
          embeds[token] = percentWidth != null
              ? '<img src="${match[3]}" style="width:${percentWidth}%;max-width:100%" />'
              : pxWidth == null
                  ? '<img src="${match[3]}" />'
                  : '<img src="${match[3]}" width="$pxWidth" />';
        } else if (match[4] != null) {
          final value = match[4]!.trim();
          final uri = Uri.tryParse(value.startsWith('http') ? value : 'https://youtu.be/$value');
          String? id;
          if (uri != null) {
            if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
              id = uri.pathSegments.first;
            } else {
              id = uri.queryParameters['v'];
              final index = uri.pathSegments.indexOf('embed');
              final shorts = uri.pathSegments.indexOf('shorts');
              final pathIndex = index >= 0 ? index : shorts;
              if ((id == null || id.isEmpty) && pathIndex >= 0 && pathIndex + 1 < uri.pathSegments.length) {
                id = uri.pathSegments[pathIndex + 1];
              }
            }
          }
          embeds[token] = id == null || id.isEmpty
              ? match[0]!
              : '<iframe src="https://www.youtube-nocookie.com/embed/$id?playsinline=1" width="560" height="315" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>';
        } else {
          embeds[token] = '<video src="${match[5]}" controls loop muted></video>';
        }
        return token;
      },
    );
    final centerBlocks = <String>[];
    var prepared = protectedSource.replaceAllMapped(
      RegExp(r'(?:˜˜˜|~~~(?:center[ \t]*(?:\r?\n)|[ \t]*(?:\r?\n))?)([\s\S]*?)(?:˜˜˜|~~~)', dotAll: true),
      (match) {
        final index = centerBlocks.length;
        centerBlocks.add(match[1] ?? '');
        return '\n\nANILIST_CENTER_BLOCK_${index}_PLACEHOLDER\n\n';
      },
    );
    final alignedBlocks = <({String body, String align})>[];
    prepared = prepared.replaceAllMapped(
      RegExp(r'<(center|div|p)\b([^>]*)>([\s\S]*?)</\1\s*>', caseSensitive: false),
      (match) {
        final tag = (match[1] ?? '').toLowerCase();
        final attrs = match[2] ?? '';
        final body = match[3] ?? '';
        final alignMatch = RegExp(r"""align\s*=\s*["']?(left|center|right|justify)""", caseSensitive: false).firstMatch(attrs);
        final styleMatch = RegExp(r"""text-align\s*:\s*(left|center|right|justify)""", caseSensitive: false).firstMatch(attrs);
        final align = tag == 'center' ? 'center' : (alignMatch?.group(1)?.toLowerCase() ?? styleMatch?.group(1)?.toLowerCase() ?? 'left');
        final index = alignedBlocks.length;
        alignedBlocks.add((body: body, align: align));
        return '\n\nANILIST_ALIGN_BLOCK_${index}_PLACEHOLDER\n\n';
      },
    );

    // Protect AniList's ~!spoiler!~ syntax before Markdown parses tildes as
    // strikethrough. Restore it as an interactive span after HTML generation.
    final spoilerBlocks = <String, String>{};
    var spoilerIndex = 0;
    prepared = prepared.replaceAllMapped(
      RegExp(r'~!([\s\S]*?)!~'),
      (match) {
        final token = 'ANILIST_SPOILER_${spoilerIndex++}_TOKEN';
        spoilerBlocks[token] = '<span class="anilist-spoiler">${match[1] ?? ''}</span>';
        return token;
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

    html = html.replaceAllMapped(
      RegExp(r"""<div\s+rel=["']spoiler["']>(.*?)</div>""", dotAll: true),
      (match) =>
          '<span class="anilist-spoiler">${match[1] ?? ''}</span>',
    );

    for (final entry in spoilerBlocks.entries) {
      html = html.replaceAll(entry.key, entry.value);
    }



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
      final centered = '<div class="anilist-center"><div class="anilist-center-content">$innerHtml</div></div>';
      html = html.replaceAll('<p>$marker</p>', centered);
      html = html.replaceAll(marker, centered);
    }
    for (var i = 0; i < alignedBlocks.length; i++) {
      final block = alignedBlocks[i];
      final inner = block.body.replaceAllMapped(
        RegExp(r'(?<!\n)\n(?!\n)'),
        (_) => '  \n',
      );
      final innerHtml = md.markdownToHtml(
        inner,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      );
      final marker = 'ANILIST_ALIGN_BLOCK_${i}_PLACEHOLDER';
      final aligned = '<div class="anilist-align-${block.align}">$innerHtml</div>';
      html = html.replaceAll('<p>$marker</p>', aligned);
      html = html.replaceAll(marker, aligned);
    }
    for (final entry in embeds.entries) {
      html = html.replaceAll(entry.key, entry.value);
    }

    // When multiple AniList image embeds share one paragraph, size them as
    // inline thumbnails so the HTML renderer can lay them out side by side.
    html = html.replaceAllMapped(
      RegExp(r'<p>((?:\s*<img\b[^>]*\/?>(?:\s*))+)</p>', caseSensitive: false),
      (match) {
        final images = RegExp(r'<img\b[^>]*\/?>(?:\s*)', caseSensitive: false)
            .allMatches(match[1] ?? '').length;
        if (images < 2) return match[0]!;
        return '<div class="anilist-image-row">${(match[1] ?? '').replaceAllMapped(RegExp(r'<img\b([^>]*)>', caseSensitive: false), (image) {
          final attrs = image[1] ?? '';
          if (RegExp(r'\bwidth\s*=', caseSensitive: false).hasMatch(attrs) || RegExp(r'width\s*:', caseSensitive: false).hasMatch(attrs)) return image[0]!;
          return '<img$attrs width="48%">';
        })}</div>';
      },
    );
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
            return {'margin': '0 0 8px 0', 'line-height': '1.45', 'max-width': '100%', 'overflow-wrap': 'anywhere'};
          case 'h1':
            return {'font-size': '1.55em', 'font-weight': '700', 'margin': '12px 0 7px 0'};
          case 'h2':
            return {'font-size': '1.35em', 'font-weight': '700', 'margin': '11px 0 6px 0'};
          case 'h3':
          case 'h4':
          case 'h5':
          case 'h6':
            return {'font-size': '1.12em', 'font-weight': '700', 'margin': '9px 0 5px 0'};
          case 'ul':
          case 'ol':
            return {'padding-left': '22px', 'margin': '5px 0 9px 0'};
          case 'li':
            return {'margin': '2px 0', 'line-height': '1.4'};
          case 'hr':
            return {'border': '0', 'border-top': '1px solid #454B58', 'margin': '12px 0'};
          case 'table':
            return {'border-collapse': 'collapse', 'width': '100%'};
          case 'th':
          case 'td':
            return {'border': '1px solid #454B58', 'padding': '6px', 'vertical-align': 'top'};
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
            return {'max-width': '100%', 'height': 'auto'};
          case 'div':
          case 'center':
            if (element.classes.contains('anilist-center') ||
                element.classes.contains('anilist-align-center') ||
                element.localName == 'center') {
              return {'text-align': 'center', 'max-width': '100%', 'width': '100%', 'overflow-wrap': 'anywhere'};
            }
            if (element.classes.contains('anilist-align-right')) return {'text-align': 'right', 'max-width': '100%', 'width': '100%'};
            if (element.classes.contains('anilist-align-justify')) return {'text-align': 'justify', 'max-width': '100%', 'width': '100%'};
            if (element.classes.contains('anilist-align-left')) return {'text-align': 'left', 'max-width': '100%', 'width': '100%'};
            if (element.classes.contains('anilist-center-content')) return {'text-align': 'center', 'max-width': '100%', 'width': '100%'};
            final align = element.attributes['align'] ?? '';
            if (align == 'center' || align == 'right' || align == 'justify') {
              return {'text-align': align, 'max-width': '100%', 'width': '100%', 'overflow-wrap': 'anywhere'};
            }
            break;
        }
        return null;
      },
      customWidgetBuilder: (element) {
        if (element.localName == 'div' && element.classes.contains('anilist-image-row')) {
          final images = element.children.where((child) => child.localName == 'img').toList();
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (final image in images)
                if ((image.attributes['src'] ?? '').isNotEmpty)
                  _MarkdownInlineImage(
                    url: image.attributes['src']!,
                    width: double.tryParse(image.attributes['width'] ?? ''),
                  ),
            ],
          );
        }
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
        if (element.localName == 'video') {
          final rawSrc = element.attributes['src'] ?? '';
          final uri = Uri.tryParse(rawSrc);
          if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
            return const SizedBox.shrink();
          }
          return _WebmMarkdownPlayer(url: uri.toString());
        }
        if (element.localName == 'img') {
          final src = element.attributes['src'];
          if (src == null || src.isEmpty) return const SizedBox.shrink();
          final width = double.tryParse(element.attributes['width'] ?? '');
          final style = element.attributes['style'] ?? '';
          final percent = RegExp(r'width\s*:\s*(\d+(?:\.\d+)?)%').firstMatch(style);
          return LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width - 32;
              final safeWidth = availableWidth.clamp(1.0, 1200.0);
              final percentage = double.tryParse(percent?.group(1) ?? '');
              final requestedWidth = percentage == null ? width : safeWidth * (percentage / 100).clamp(0.01, 1.0);
              final displayWidth = requestedWidth == null
                  ? safeWidth
                  : requestedWidth.clamp(1, safeWidth).toDouble();
              return GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  builder: (_) => _MarkdownImageViewer(url: src),
                ),
                child: CachedNetworkImage(
                imageUrl: src,
                httpHeaders: {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
                  'Referer': Uri.tryParse(src)?.origin ?? 'https://anilist.co/',
                },
                width: displayWidth,
                fit: BoxFit.contain,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => SizedBox(
                  width: displayWidth,
                  height: displayWidth * 0.56,
                ),
                errorWidget: (_, __, ___) => SizedBox(width: displayWidth, height: displayWidth * 0.56, child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38))),
                ),
              );
            },
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

class _MarkdownInlineImage extends StatelessWidget {
  const _MarkdownInlineImage({required this.url, this.width});
  final String url;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 48;
    final displayWidth = (width == null ? available * .48 : available * (width! > 1 ? width! / available : width!))
        .clamp(80.0, available * .5);
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .1),
        builder: (_) => _MarkdownImageViewer(url: url),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
            'Referer': 'https://anilist.co/',
          },
          width: displayWidth,
          fit: BoxFit.contain,
          fadeInDuration: Duration.zero,
          placeholder: (_, __) => SizedBox(width: displayWidth, height: displayWidth * .56),
          errorWidget: (_, __, ___) => SizedBox(width: displayWidth, height: displayWidth * .56, child: const Icon(Icons.broken_image_outlined)),
        ),
      ),
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
      // YouTube may return player error 153 when the WebView request has
      // no referrer. Supply a YouTube referrer and a mobile browser user-agent.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(
        widget.uri,
        headers: const {'Referer': 'https://www.youtube.com/', 'Origin': 'https://www.youtube.com'},
      );
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

/// Native inline player for AniList's webm(URL) embed syntax.
class _WebmMarkdownPlayer extends StatefulWidget {
  const _WebmMarkdownPlayer({required this.url});
  final String url;
  @override
  State<_WebmMarkdownPlayer> createState() => _WebmMarkdownPlayerState();
}
class _WebmMarkdownPlayerState extends State<_WebmMarkdownPlayer> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _open();
  }
  Future<void> _open() async {
    try {
      await _player.open(Media(widget.url), play: false);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.black,
        child: Text('Video tidak dapat diputar: $_error',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Video(controller: _controller),
      ),
    );
  }
}


/// Full-screen image preview with pinch-to-zoom and a save-to-gallery action.
class _MarkdownImageViewer extends StatefulWidget {
  const _MarkdownImageViewer({required this.url});

  final String url;

  @override
  State<_MarkdownImageViewer> createState() => _MarkdownImageViewerState();
}

class _MarkdownImageViewerState extends State<_MarkdownImageViewer> {
  bool _saving = false;

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
            'Referer': Uri.tryParse(widget.url)?.origin ?? 'https://anilist.co/',
          },
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Gambar kosong');
      }
      final name = Uri.tryParse(widget.url)?.pathSegments.lastOrNull;
      final safeName = (name == null || name.isEmpty) ? 'anilist-image.jpg' : name;
      await Gal.putImageBytes(Uint8List.fromList(bytes), name: safeName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gambar berhasil disimpan ke galeri')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan gambar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.url,
                    fit: BoxFit.contain,
                    httpHeaders: {
                      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
                      'Referer': Uri.tryParse(widget.url)?.origin ?? 'https://anilist.co/',
                    },
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                tooltip: 'Kembali',
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: _saving ? null : _download,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.5),
                  foregroundColor: Colors.black,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.download),
                tooltip: 'Simpan ke galeri',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
