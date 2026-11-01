import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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
          SelectableText(text, style: const TextStyle(color: Color(0xFFE1E2E8), height: 1.45, fontSize: 14)),
          if (likes > 0) ...[const SizedBox(height: 9), Row(children: [const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFED6A8B)), const SizedBox(width: 5), Text('$likes', style: const TextStyle(color: Color(0xFF9497A1), fontSize: 11))])],
        ])),
      ]),
    );
  }
  Widget _avatarFallback() => Container(color: const Color(0xFF424550), alignment: Alignment.center, child: const Icon(Icons.person_rounded, color: Colors.white70, size: 22));
}