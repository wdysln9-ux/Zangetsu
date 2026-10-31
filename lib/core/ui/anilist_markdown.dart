import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Renders AniList descriptions and synopses as rich Markdown.
class AniListMarkdown extends StatelessWidget {
  const AniListMarkdown({
    super.key,
    required this.data,
    this.textStyle,
  });

  final String data;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final markdown = data.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    final base = textStyle ?? Theme.of(context).textTheme.bodyMedium!;
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      h1: base.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
      h2: base.copyWith(fontSize: 21, fontWeight: FontWeight.w700),
      h3: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h4: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      blockquote: base.copyWith(color: AppColors.textSecondary),
      code: base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: AppColors.surface2,
      ),
      a: base.copyWith(
        color: AppColors.accent,
        decoration: TextDecoration.underline,
      ),
    );
    return MarkdownBody(
      data: markdown,
      styleSheet: sheet,
      onTapLink: (text, href, title) {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
