import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injector.dart';
import '../../core/theme/app_text.dart';

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});
  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  static const _endpoint = 'https://graphql.anilist.co';
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  int _page = 1;
  bool _loading = false, _hasNext = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); _scroll.addListener(_onScroll); }
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }
  void _onScroll() { if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) _load(); }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasNext && !refresh)) return;
    if (refresh) { _page = 1; _hasNext = true; _posts.clear(); }
    setState(() { _loading = true; _error = null; });
    const query = r'''
      query($page: Int) {
        Page(page: $page, perPage: 25) {
          pageInfo { hasNextPage }
          activities(type: TEXT, sort: ID_DESC) {
            ... on TextActivity { id text(asHtml: false) createdAt user { id name avatar { large } } likeCount }
          }
        }
      }
    ''';
    try {
      final response = await sl<Dio>().post<dynamic>(_endpoint,
        data: {'query': query, 'variables': {'page': _page}},
        options: Options(headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'}, validateStatus: (s) => s != null && s < 500));
      final body = response.data;
      if (body is! Map || body['data'] is! Map) {
        final errors = body is Map && body['errors'] is List ? (body['errors'] as List).map((e) => e is Map ? e['message'] : e).join('\n') : 'AniList tidak mengembalikan data.';
        throw Exception(errors);
      }
      final page = (body['data'] as Map)['Page'];
      if (page is! Map) throw Exception('Feed AniList tidak tersedia.');
      final items = page['activities'];
      if (items is List) for (final item in items.whereType<Map>()) _posts.add(Map<String, dynamic>.from(item));
      _hasNext = page['pageInfo'] is Map && (page['pageInfo'] as Map)['hasNextPage'] == true;
      _page++;
    } catch (e) { _error = e.toString().replaceFirst('Exception: ', ''); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  String _time(dynamic value) {
    final seconds = (value as num?)?.toInt(); if (seconds == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF202127),
    appBar: AppBar(backgroundColor: const Color(0xFF202127), elevation: 0,
      title: Row(children: [const Icon(Icons.forum_rounded, color: Color(0xFF8EA1E1), size: 22), const SizedBox(width: 10), Text('Global Chat', style: AppText.barTitle)]),
      actions: [IconButton(tooltip: 'Refresh', onPressed: () => _load(refresh: true), icon: const Icon(Icons.refresh_rounded))]),
    body: RefreshIndicator(onRefresh: () => _load(refresh: true),
      child: _posts.isEmpty && _loading ? const Center(child: CircularProgressIndicator())
      : _posts.isEmpty && _error != null ? ListView(children: [const SizedBox(height: 180), Center(child: Text(_error!, textAlign: TextAlign.center)), TextButton(onPressed: () => _load(refresh: true), child: const Text('Coba lagi'))])
      : ListView.separated(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        itemCount: _posts.length + (_loading || _error != null ? 1 : 0), separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          if (index >= _posts.length) return _error != null ? TextButton(onPressed: _load, child: Text('Gagal memuat: $_error · Coba lagi')) : const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          return _postCard(_posts[index]);
        })),
  );

  Widget _postCard(Map<String, dynamic> post) {
    final user = post['user'] is Map ? post['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? user['avatar']['large'] : null;
    final name = (user['name'] ?? 'AniList User').toString();
    final text = (post['text'] ?? '').toString().trim();
    final likes = (post['likeCount'] as num?)?.toInt() ?? 0;
    return Container(padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
      decoration: BoxDecoration(color: const Color(0xFF2B2D35), borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(width: 40, height: 40,
          child: avatar is String && avatar.isNotEmpty ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover, errorWidget: (_, _, _) => _avatarFallback()) : _avatarFallback())),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 7, children: [
            Text(name, style: const TextStyle(color: Color(0xFFB9C5FF), fontWeight: FontWeight.w700, fontSize: 14)),
            Text(_time(post['createdAt']), style: const TextStyle(color: Color(0xFF9497A1), fontSize: 11)),
          ]),
          const SizedBox(height: 7),
          _MarkdownContent(text: text),
          if (likes > 0) ...[const SizedBox(height: 9), Row(children: [const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFED6A8B)), const SizedBox(width: 5), Text('$likes', style: const TextStyle(color: Color(0xFF9497A1), fontSize: 11))])],
        ])),
      ]),
    );
  }

  Widget _avatarFallback() => Container(color: const Color(0xFF424550), alignment: Alignment.center, child: const Icon(Icons.person_rounded, color: Colors.white70, size: 22));
}


class _MarkdownContent extends StatelessWidget {
  const _MarkdownContent({required this.text});
  final String text;

  static const _color = Color(0xFFE1E2E8);
  static const _muted = Color(0xFFB8BBC7);
  static const _link = Color(0xFF8EA1E1);

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    final markdownLines = <String>[];
    void flush() {
      if (markdownLines.isEmpty) return;
      final prepared = _prepare(markdownLines.join('\n'));
      final nodes = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
      ).parseLines(prepared.split('\n'));
      widgets.addAll(nodes.map(_block));
      markdownLines.clear();
    }
    for (final line in lines) {
      final match = RegExp(r'^\s*(youtube|webm)\((https?://[^)\s]+)\)\s*
  }

  String _prepare(String source) {
    var value = source.replaceAllMapped(
      RegExp(r'~~~([\s\S]*?)~~~'),
      (m) => '<center>' + m.group(1)! + '</center>',
    );
    value = value.replaceAllMapped(
      RegExp(r'img(\d{1,4})\((https?://[^)\s]+)\)'),
      (m) => '<img alt="Image" src="' + m.group(2)! +
          '" width="' + m.group(1)! + '">',
    );
    value = value.replaceAllMapped(
      RegExp(r'~!([\s\S]+?)!~'),
      (m) => '<span data-anilist-spoiler="true">' +
          m.group(1)!.replaceAll('&', '&amp;').replaceAll('<', '&lt;') +
          '</span>',
    );
    final lines = value.split('\n');
    for (var i = 1; i < lines.length; i++) {
      if (RegExp(r'^={2,}\s*
    if (node is md.Text) return _paragraph([node]);
    if (node is! md.Element) return const SizedBox.shrink();
    final tag = node.tag;
    if (tag == 'ul' || tag == 'ol') {
      var number = 0;
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (node.children ?? const <md.Node>[]).map((child) {
            if (child is! md.Element || child.tag != 'li') return _block(child);
            number++;
            return Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    child: Text(tag == 'ol' ? '$number.' : '•',
                      style: const TextStyle(color: _muted, fontSize: 14)),
                  ),
                  Expanded(child: _inlineBlock(child.children ?? const [])),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    if (tag == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _link, width: 3)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: _muted, fontStyle: FontStyle.italic,
            height: 1.45, fontSize: 14),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    if (tag == 'pre') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SelectableText(node.textContent,
          style: const TextStyle(color: Color(0xFFD6D9E5),
            fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      );
    }
    if (tag == 'hr') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(color: Color(0xFF454854), height: 1),
      );
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final alt = node.attributes['alt'] ?? 'Image';
      if (src == null || src.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt,
                style: const TextStyle(color: _muted))),
          ),
        ),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'center' ||
        tag == 'div' && node.attributes['align'] == 'center' ||
        tag == 'center') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Center(child: _inlineBlock(node.children ?? const [])),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'right' ||
        tag == 'div' && node.attributes['align'] == 'right') {
      return Align(
        alignment: Alignment.centerRight,
        child: _inlineBlock(node.children ?? const []),
      );
    }
    final heading = RegExp(r'^h[1-5]$').hasMatch(tag);
    if (heading) {
      final level = int.parse(tag.substring(1));
      final size = [20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    return _paragraph(node.children ?? const []);
  }

  Widget _paragraph(List<md.Node> nodes) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SelectableText.rich(TextSpan(
      style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
      children: nodes.map(_span).toList(),
    )),
  );

  Widget _inlineBlock(List<md.Node> nodes) => SelectableText.rich(TextSpan(
    style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
    children: nodes.map(_span).toList(),
  ));

  TextSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return const TextSpan();
    final tag = node.tag;
    final children = (node.children ?? const <md.Node>[]).map(_span).toList();
    TextStyle? style;
    if (tag == 'strong' || tag == 'b') {
      style = const TextStyle(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else if (tag == 'del' || tag == 'strike') {
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    } else if (tag == 'code') {
      style = const TextStyle(fontFamily: 'monospace', fontSize: 12,
        color: Color(0xFFFFC98B), backgroundColor: Color(0xFF1D1F26));
    } else if (tag == 'a') {
      style = const TextStyle(color: _link, decoration: TextDecoration.underline);
    }
    if (tag == 'br') return const TextSpan(text: '\n');
    return TextSpan(style: style, children: children);
  }
}
,
        caseSensitive: false).firstMatch(line);
      if (match == null) {
        markdownLines.add(line);
      } else {
        flush();
        widgets.add(_videoEmbed(match.group(1)!, match.group(2)!));
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _block(md.Node node) {
    if (node is md.Text) return _paragraph([node]);
    if (node is! md.Element) return const SizedBox.shrink();
    final tag = node.tag;
    if (tag == 'ul' || tag == 'ol') {
      var number = 0;
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (node.children ?? const <md.Node>[]).map((child) {
            if (child is! md.Element || child.tag != 'li') return _block(child);
            number++;
            return Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    child: Text(tag == 'ol' ? '$number.' : '•',
                      style: const TextStyle(color: _muted, fontSize: 14)),
                  ),
                  Expanded(child: _inlineBlock(child.children ?? const [])),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    if (tag == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _link, width: 3)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: _muted, fontStyle: FontStyle.italic,
            height: 1.45, fontSize: 14),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    if (tag == 'pre') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SelectableText(node.textContent,
          style: const TextStyle(color: Color(0xFFD6D9E5),
            fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      );
    }
    if (tag == 'hr') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(color: Color(0xFF454854), height: 1),
      );
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final alt = node.attributes['alt'] ?? 'Image';
      if (src == null || src.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt,
                style: const TextStyle(color: _muted))),
          ),
        ),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'center' ||
        tag == 'div' && node.attributes['align'] == 'center' ||
        tag == 'center') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Center(child: _inlineBlock(node.children ?? const [])),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'right' ||
        tag == 'div' && node.attributes['align'] == 'right') {
      return Align(
        alignment: Alignment.centerRight,
        child: _inlineBlock(node.children ?? const []),
      );
    }
    final heading = RegExp(r'^h[1-5]$').hasMatch(tag);
    if (heading) {
      final level = int.parse(tag.substring(1));
      final size = [20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    return _paragraph(node.children ?? const []);
  }

  Widget _paragraph(List<md.Node> nodes) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SelectableText.rich(TextSpan(
      style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
      children: nodes.map(_span).toList(),
    )),
  );

  Widget _inlineBlock(List<md.Node> nodes) => SelectableText.rich(TextSpan(
    style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
    children: nodes.map(_span).toList(),
  ));

  TextSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return const TextSpan();
    final tag = node.tag;
    final children = (node.children ?? const <md.Node>[]).map(_span).toList();
    TextStyle? style;
    if (tag == 'strong' || tag == 'b') {
      style = const TextStyle(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else if (tag == 'del' || tag == 'strike') {
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    } else if (tag == 'code') {
      style = const TextStyle(fontFamily: 'monospace', fontSize: 12,
        color: Color(0xFFFFC98B), backgroundColor: Color(0xFF1D1F26));
    } else if (tag == 'a') {
      style = const TextStyle(color: _link, decoration: TextDecoration.underline);
    }
    if (tag == 'br') return const TextSpan(text: '\n');
    return TextSpan(style: style, children: children);
  }
}
).hasMatch(lines[i])) {
        lines[i - 1] = '<h1>' + lines[i - 1] + '</h1>';
        lines[i] = '';
      } else if (RegExp(r'^-{2,}\s*
    if (node is md.Text) return _paragraph([node]);
    if (node is! md.Element) return const SizedBox.shrink();
    final tag = node.tag;
    if (tag == 'ul' || tag == 'ol') {
      var number = 0;
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (node.children ?? const <md.Node>[]).map((child) {
            if (child is! md.Element || child.tag != 'li') return _block(child);
            number++;
            return Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    child: Text(tag == 'ol' ? '$number.' : '•',
                      style: const TextStyle(color: _muted, fontSize: 14)),
                  ),
                  Expanded(child: _inlineBlock(child.children ?? const [])),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    if (tag == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _link, width: 3)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: _muted, fontStyle: FontStyle.italic,
            height: 1.45, fontSize: 14),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    if (tag == 'pre') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SelectableText(node.textContent,
          style: const TextStyle(color: Color(0xFFD6D9E5),
            fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      );
    }
    if (tag == 'hr') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(color: Color(0xFF454854), height: 1),
      );
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final alt = node.attributes['alt'] ?? 'Image';
      if (src == null || src.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt,
                style: const TextStyle(color: _muted))),
          ),
        ),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'center' ||
        tag == 'div' && node.attributes['align'] == 'center' ||
        tag == 'center') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Center(child: _inlineBlock(node.children ?? const [])),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'right' ||
        tag == 'div' && node.attributes['align'] == 'right') {
      return Align(
        alignment: Alignment.centerRight,
        child: _inlineBlock(node.children ?? const []),
      );
    }
    final heading = RegExp(r'^h[1-5]$').hasMatch(tag);
    if (heading) {
      final level = int.parse(tag.substring(1));
      final size = [20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    return _paragraph(node.children ?? const []);
  }

  Widget _paragraph(List<md.Node> nodes) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SelectableText.rich(TextSpan(
      style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
      children: nodes.map(_span).toList(),
    )),
  );

  Widget _inlineBlock(List<md.Node> nodes) => SelectableText.rich(TextSpan(
    style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
    children: nodes.map(_span).toList(),
  ));

  TextSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return const TextSpan();
    final tag = node.tag;
    final children = (node.children ?? const <md.Node>[]).map(_span).toList();
    TextStyle? style;
    if (tag == 'strong' || tag == 'b') {
      style = const TextStyle(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else if (tag == 'del' || tag == 'strike') {
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    } else if (tag == 'code') {
      style = const TextStyle(fontFamily: 'monospace', fontSize: 12,
        color: Color(0xFFFFC98B), backgroundColor: Color(0xFF1D1F26));
    } else if (tag == 'a') {
      style = const TextStyle(color: _link, decoration: TextDecoration.underline);
    }
    if (tag == 'br') return const TextSpan(text: '\n');
    return TextSpan(style: style, children: children);
  }
}
,
        caseSensitive: false).firstMatch(line);
      if (match == null) {
        markdownLines.add(line);
      } else {
        flush();
        widgets.add(_videoEmbed(match.group(1)!, match.group(2)!));
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _block(md.Node node) {
    if (node is md.Text) return _paragraph([node]);
    if (node is! md.Element) return const SizedBox.shrink();
    final tag = node.tag;
    if (tag == 'ul' || tag == 'ol') {
      var number = 0;
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (node.children ?? const <md.Node>[]).map((child) {
            if (child is! md.Element || child.tag != 'li') return _block(child);
            number++;
            return Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    child: Text(tag == 'ol' ? '$number.' : '•',
                      style: const TextStyle(color: _muted, fontSize: 14)),
                  ),
                  Expanded(child: _inlineBlock(child.children ?? const [])),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    if (tag == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _link, width: 3)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: _muted, fontStyle: FontStyle.italic,
            height: 1.45, fontSize: 14),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    if (tag == 'pre') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SelectableText(node.textContent,
          style: const TextStyle(color: Color(0xFFD6D9E5),
            fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      );
    }
    if (tag == 'hr') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(color: Color(0xFF454854), height: 1),
      );
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final alt = node.attributes['alt'] ?? 'Image';
      if (src == null || src.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt,
                style: const TextStyle(color: _muted))),
          ),
        ),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'center' ||
        tag == 'div' && node.attributes['align'] == 'center' ||
        tag == 'center') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Center(child: _inlineBlock(node.children ?? const [])),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'right' ||
        tag == 'div' && node.attributes['align'] == 'right') {
      return Align(
        alignment: Alignment.centerRight,
        child: _inlineBlock(node.children ?? const []),
      );
    }
    final heading = RegExp(r'^h[1-5]$').hasMatch(tag);
    if (heading) {
      final level = int.parse(tag.substring(1));
      final size = [20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    return _paragraph(node.children ?? const []);
  }

  Widget _paragraph(List<md.Node> nodes) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SelectableText.rich(TextSpan(
      style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
      children: nodes.map(_span).toList(),
    )),
  );

  Widget _inlineBlock(List<md.Node> nodes) => SelectableText.rich(TextSpan(
    style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
    children: nodes.map(_span).toList(),
  ));

  TextSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return const TextSpan();
    final tag = node.tag;
    final children = (node.children ?? const <md.Node>[]).map(_span).toList();
    TextStyle? style;
    if (tag == 'strong' || tag == 'b') {
      style = const TextStyle(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else if (tag == 'del' || tag == 'strike') {
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    } else if (tag == 'code') {
      style = const TextStyle(fontFamily: 'monospace', fontSize: 12,
        color: Color(0xFFFFC98B), backgroundColor: Color(0xFF1D1F26));
    } else if (tag == 'a') {
      style = const TextStyle(color: _link, decoration: TextDecoration.underline);
    }
    if (tag == 'br') return const TextSpan(text: '\n');
    return TextSpan(style: style, children: children);
  }
}
).hasMatch(lines[i])) {
        lines[i - 1] = '<h2>' + lines[i - 1] + '</h2>';
        lines[i] = '';
      }
    }
    return lines.join('\n');
  }

  Widget _videoEmbed(String type, String url) {
    final youtube = type.toLowerCase() == 'youtube';
    final uri = Uri.tryParse(url);
    final id = youtube
        ? (uri?.queryParameters['v'] ??
            RegExp(r'youtu\.be/([^?&/]+)').firstMatch(url)?.group(1) ??
            RegExp(r'/embed/([^?&/]+)').firstMatch(url)?.group(1))
        : null;
    return InkWell(
      onTap: uri == null ? null : () => launchUrl(uri,
          mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          if (youtube && id != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: 'https://img.youtube.com/vi/' + id + '/hqdefault.jpg',
                width: 112, height: 63, fit: BoxFit.cover,
                errorWidget: (_, _, _) => _videoIcon(youtube)),
            )
          else
            _videoIcon(youtube),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(youtube ? 'YouTube video' : 'Video',
                style: const TextStyle(color: Color(0xFFE1E2E8),
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              const Text('Ketuk untuk membuka',
                style: TextStyle(color: Color(0xFFB8BBC7), fontSize: 11)),
            ],
          )),
          const Icon(Icons.open_in_new, color: Color(0xFF8EA1E1), size: 17),
        ]),
      ),
    );
  }

  Widget _videoIcon(bool youtube) => Container(
    width: 112, height: 63,
    decoration: BoxDecoration(color: const Color(0xFF343743),
      borderRadius: BorderRadius.circular(5)),
    child: Icon(youtube ? Icons.play_circle_fill : Icons.movie,
      color: const Color(0xFF8EA1E1), size: 34),
  );

  Widget _block(md.Node node) {
    if (node is md.Text) return _paragraph([node]);
    if (node is! md.Element) return const SizedBox.shrink();
    final tag = node.tag;
    if (tag == 'ul' || tag == 'ol') {
      var number = 0;
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (node.children ?? const <md.Node>[]).map((child) {
            if (child is! md.Element || child.tag != 'li') return _block(child);
            number++;
            return Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    child: Text(tag == 'ol' ? '$number.' : '•',
                      style: const TextStyle(color: _muted, fontSize: 14)),
                  ),
                  Expanded(child: _inlineBlock(child.children ?? const [])),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    if (tag == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _link, width: 3)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: _muted, fontStyle: FontStyle.italic,
            height: 1.45, fontSize: 14),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    if (tag == 'pre') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SelectableText(node.textContent,
          style: const TextStyle(color: Color(0xFFD6D9E5),
            fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      );
    }
    if (tag == 'hr') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(color: Color(0xFF454854), height: 1),
      );
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final alt = node.attributes['alt'] ?? 'Image';
      if (src == null || src.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt,
                style: const TextStyle(color: _muted))),
          ),
        ),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'center' ||
        tag == 'div' && node.attributes['align'] == 'center' ||
        tag == 'center') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Center(child: _inlineBlock(node.children ?? const [])),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'right' ||
        tag == 'div' && node.attributes['align'] == 'right') {
      return Align(
        alignment: Alignment.centerRight,
        child: _inlineBlock(node.children ?? const []),
      );
    }
    final heading = RegExp(r'^h[1-5]$').hasMatch(tag);
    if (heading) {
      final level = int.parse(tag.substring(1));
      final size = [20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    return _paragraph(node.children ?? const []);
  }

  Widget _paragraph(List<md.Node> nodes) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SelectableText.rich(TextSpan(
      style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
      children: nodes.map(_span).toList(),
    )),
  );

  Widget _inlineBlock(List<md.Node> nodes) => SelectableText.rich(TextSpan(
    style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
    children: nodes.map(_span).toList(),
  ));

  TextSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return const TextSpan();
    final tag = node.tag;
    final children = (node.children ?? const <md.Node>[]).map(_span).toList();
    TextStyle? style;
    if (tag == 'strong' || tag == 'b') {
      style = const TextStyle(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else if (tag == 'del' || tag == 'strike') {
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    } else if (tag == 'code') {
      style = const TextStyle(fontFamily: 'monospace', fontSize: 12,
        color: Color(0xFFFFC98B), backgroundColor: Color(0xFF1D1F26));
    } else if (tag == 'a') {
      style = const TextStyle(color: _link, decoration: TextDecoration.underline);
    }
    if (tag == 'br') return const TextSpan(text: '\n');
    return TextSpan(style: style, children: children);
  }
}
,
        caseSensitive: false).firstMatch(line);
      if (match == null) {
        markdownLines.add(line);
      } else {
        flush();
        widgets.add(_videoEmbed(match.group(1)!, match.group(2)!));
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _block(md.Node node) {
    if (node is md.Text) return _paragraph([node]);
    if (node is! md.Element) return const SizedBox.shrink();
    final tag = node.tag;
    if (tag == 'ul' || tag == 'ol') {
      var number = 0;
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (node.children ?? const <md.Node>[]).map((child) {
            if (child is! md.Element || child.tag != 'li') return _block(child);
            number++;
            return Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 19,
                    child: Text(tag == 'ol' ? '$number.' : '•',
                      style: const TextStyle(color: _muted, fontSize: 14)),
                  ),
                  Expanded(child: _inlineBlock(child.children ?? const [])),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    if (tag == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _link, width: 3)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: _muted, fontStyle: FontStyle.italic,
            height: 1.45, fontSize: 14),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    if (tag == 'pre') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F26),
          borderRadius: BorderRadius.circular(7),
        ),
        child: SelectableText(node.textContent,
          style: const TextStyle(color: Color(0xFFD6D9E5),
            fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      );
    }
    if (tag == 'hr') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(color: Color(0xFF454854), height: 1),
      );
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final alt = node.attributes['alt'] ?? 'Image';
      if (src == null || src.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.network(src, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(alt,
                style: const TextStyle(color: _muted))),
          ),
        ),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'center' ||
        tag == 'div' && node.attributes['align'] == 'center' ||
        tag == 'center') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Center(child: _inlineBlock(node.children ?? const [])),
      );
    }
    if (tag == 'p' && node.attributes['align'] == 'right' ||
        tag == 'div' && node.attributes['align'] == 'right') {
      return Align(
        alignment: Alignment.centerRight,
        child: _inlineBlock(node.children ?? const []),
      );
    }
    final heading = RegExp(r'^h[1-5]$').hasMatch(tag);
    if (heading) {
      final level = int.parse(tag.substring(1));
      final size = [20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          child: _inlineBlock(node.children ?? const []),
        ),
      );
    }
    return _paragraph(node.children ?? const []);
  }

  Widget _paragraph(List<md.Node> nodes) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SelectableText.rich(TextSpan(
      style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
      children: nodes.map(_span).toList(),
    )),
  );

  Widget _inlineBlock(List<md.Node> nodes) => SelectableText.rich(TextSpan(
    style: const TextStyle(color: _color, height: 1.45, fontSize: 14),
    children: nodes.map(_span).toList(),
  ));

  TextSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return const TextSpan();
    final tag = node.tag;
    final children = (node.children ?? const <md.Node>[]).map(_span).toList();
    TextStyle? style;
    if (tag == 'strong' || tag == 'b') {
      style = const TextStyle(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else if (tag == 'del' || tag == 'strike') {
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    } else if (tag == 'code') {
      style = const TextStyle(fontFamily: 'monospace', fontSize: 12,
        color: Color(0xFFFFC98B), backgroundColor: Color(0xFF1D1F26));
    } else if (tag == 'a') {
      style = const TextStyle(color: _link, decoration: TextDecoration.underline);
    }
    if (tag == 'br') return const TextSpan(text: '\n');
    return TextSpan(style: style, children: children);
  }
}
