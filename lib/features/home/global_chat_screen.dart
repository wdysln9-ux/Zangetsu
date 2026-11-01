import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/metadata/synopsis_translator.dart';
import '../../core/playback/subtitle_translate_service.dart';
import '../../core/ui/anilist_markdown.dart';

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  static const _endpoint = 'https://graphql.anilist.co';
  static const _background = Color(0xFF0D1018);
  static const _surface = Color(0xFF171C27);
  static const _muted = Color(0xFF8995A5);

  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  int _page = 1;
  bool _loading = false;
  bool _hasNext = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  // The feed is reversed: the newest activity stays at the bottom. Scrolling
  // upward reaches older activities and requests the next AniList page.
  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasNext) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 280) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasNext && !refresh)) return;
    if (refresh) {
      _page = 1;
      _hasNext = true;
      _posts.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    const query = r'''
      query($page: Int) {
        Page(page: $page, perPage: 25) {
          pageInfo { hasNextPage }
          activities(type: TEXT, sort: ID_DESC) {
            ... on TextActivity {
              id text(asHtml: false) createdAt
              user { id name avatar { large } }
            }
          }
        }
      }
    ''';

    try {
      final response = await sl<Dio>().post<dynamic>(
        _endpoint,
        data: {'query': query, 'variables': {'page': _page}},
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final body = response.data;
      if (body is! Map || body['data'] is! Map) {
        final errors = body is Map && body['errors'] is List
            ? (body['errors'] as List)
                .map((e) => e is Map ? e['message'] : e)
                .join('\n')
            : 'AniList tidak mengembalikan data.';
        throw Exception(errors);
      }
      final page = (body['data'] as Map)['Page'];
      if (page is! Map) throw Exception('Feed AniList tidak tersedia.');
      final items = page['activities'];
      if (items is List) {
        final incoming = items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (refresh) {
          _posts
            ..clear()
            ..addAll(incoming);
        } else {
          final known = _posts.map((post) => post['id']).toSet();
          _posts.addAll(
            incoming.where((post) => !known.contains(post['id'])),
          );
        }
      }
      _hasNext = page['pageInfo'] is Map &&
          (page['pageInfo'] as Map)['hasNextPage'] == true;
      _page++;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshFromGesture() async {
    await _load(refresh: true);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _time(dynamic value) {
    final seconds = (value as num?)?.toInt();
    if (seconds == null) return '';
    final date =
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            _channelTabs(),
            _notice(),
            Expanded(child: _feed()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: _background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          _roundButton(
            Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF14233D),
              border: Border.all(color: const Color(0xFF347BEA), width: 1.5),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.forum_rounded,
                color: Color(0xFF438BFF), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat Global',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF438BFF), size: 10),
                    SizedBox(width: 8),
                    Text('online',
                        style: TextStyle(color: _muted, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          _roundButton(Icons.share_rounded, onTap: () {}),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF1B222E),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 27),
        ),
      ),
    );
  }

  Widget _channelTabs() {
    return Container(
      color: _background,
      padding: const EdgeInsets.fromLTRB(26, 0, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF4388F5),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Text('#Global',
                style: TextStyle(
                    color: Color(0xFF071322),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF171C25),
              border: Border.all(color: const Color(0xFF242B37)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFF4B515D), size: 21),
                SizedBox(width: 8),
                Text('tes',
                    style: TextStyle(color: Color(0xFF4B515D), fontSize: 17)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF211D17),
        border: Border(
          top: BorderSide(color: Color(0xFF55401D)),
          bottom: BorderSide(color: Color(0xFF55401D)),
        ),
      ),
      child: const Text(
        '📌 Global chat saat ini masih dikembangkan dan belum banyak fitur yg tersedia, mohon bersabar untuk menunggu update selanjutnya yah 🥰🙏',
        style: TextStyle(
            color: Color(0xFFD0D0D0), fontSize: 12, height: 1.35),
      ),
    );
  }

  Widget _feed() {
    if (_posts.isEmpty && _loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4388F5)));
    }
    if (_posts.isEmpty && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted)),
            TextButton(
              onPressed: () => _load(refresh: true),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Pulling upward while already at the oldest edge refreshes the feed.
        if (notification is OverscrollNotification &&
            notification.overscroll > 0 &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent) {
          _refreshFromGesture();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        itemCount: _posts.length + (_loading || _error != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: _error != null
                    ? TextButton(
                        onPressed: _load,
                        child: Text('Gagal memuat: $_error · Coba lagi'),
                      )
                    : const CircularProgressIndicator(
                        color: Color(0xFF4388F5)),
              ),
            );
          }
          return _postCard(_posts[index]);
        },
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final user = post['user'] is Map ? post['user'] as Map : const {};
    final avatar = user['avatar'] is Map ? user['avatar']['large'] : null;
    final name = (user['name'] ?? 'AniList User').toString();
    final userId = (user['id'] ?? '').toString();
    final rawText = (post['text'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: 42,
              height: 42,
              child: avatar is String && avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                if (userId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('#$userId',
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ],
                const SizedBox(height: 11),
                _messageBubble(rawText, post),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(String rawText, Map<String, dynamic> post) {
    return FutureBuilder<String?>(
      future: SynopsisTranslator.instance.translateTextToIndonesian(rawText),
      builder: (context, snapshot) {
        final translated = snapshot.data;
        final displayText = translated != null && translated.trim().isNotEmpty
            ? SubtitleTranslateService.naturalizeIndonesian(translated)
            : rawText;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: const Color(0xFF252D3B), width: 1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AniListMarkdown(
                data: displayText,
                textStyle: const TextStyle(
                  color: Color(0xFFF1F2F5),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _clock(post['createdAt']),
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _clock(dynamic value) {
    final seconds = (value as num?)?.toInt();
    if (seconds == null) return '';
    final date =
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _avatarFallback() => Container(
        color: const Color(0xFF343B49),
        alignment: Alignment.center,
        child: const Icon(Icons.person_rounded,
            color: Colors.white70, size: 27),
      );

  // Visual-only composer, as requested: it does not accept or send messages.
  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        color: _background,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2330),
            borderRadius: BorderRadius.circular(34),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pesan ke #Global...',
                  style: TextStyle(color: Color(0xFF91A096), fontSize: 14),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Color(0xFF0C111B), shape: BoxShape.circle),
                child: const Icon(Icons.gif_box_outlined,
                    color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
