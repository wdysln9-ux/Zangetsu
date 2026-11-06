import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/metadata/synopsis_translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/anilist_markdown.dart';
import '../../core/profiles/viewer_profile.dart';
import '../../core/profiles/viewer_profile_avatar.dart';
import '../auth/auth_cubit.dart';

class AnimeCommunityTab extends StatefulWidget {
  const AnimeCommunityTab({super.key, required this.title, required this.anilistId, required this.malId, required this.reviews});
  final String title;
  final int? anilistId, malId;
  final bool reviews;
  @override
  State<AnimeCommunityTab> createState() => _AnimeCommunityTabState();
}

class _AnimeCommunityTabState extends State<AnimeCommunityTab> {
  late Future<List<Map<String, dynamic>>> future;
  int? mediaId;
  @override
  void initState() { super.initState(); future = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    final api = sl<AniListService>().api;
    mediaId = await api.communityMediaId(anilistId: widget.anilistId, malId: widget.malId, title: widget.title);
    if (mediaId == null) return [];
    return widget.reviews ? api.fetchReviews(mediaId!) : api.fetchThreads(mediaId!);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final rows = s.data ?? [];
      if (rows.isEmpty) return Center(child: Text(mediaId == null ? 'Anime tidak ditemukan di AniList.' : widget.reviews ? 'Belum ada ulasan.' : 'Belum ada utas.'));
      return RefreshIndicator(
        onRefresh: () async { setState(() => future = load()); await future; },
        child: ListView.separated(
          padding: const EdgeInsets.all(14), itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => widget.reviews
            ? _ReviewCard(data: rows[i], anime: widget.title)
            : _ThreadCard(data: rows[i], anime: widget.title),
        ),
      );
    },
  );
}

Map<String, String> _anilistImageHeaders(String url) => {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
  'Referer': 'https://anilist.co/',
};

ImageProvider? _anilistAvatar(Object? raw) {
  final url = raw?.toString() ?? '';
  if (url.isEmpty) return null;
  return CachedNetworkImageProvider(url, headers: _anilistImageHeaders(url));
}

int _likedCount(Map data) {
  final rating = (data['rating'] as num?)?.toInt() ?? 0;
  final amount = (data['ratingAmount'] as num?)?.toInt() ?? 0;
  return ((rating.clamp(0, 100) * amount) / 100).round();
}

String _dateLabel(Object? raw) {
  final seconds = (raw as num?)?.toInt();
  if (seconds == null || seconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.data, required this.anime});
  final Map<String, dynamic> data;
  final String anime;
  @override
  Widget build(BuildContext context) {
    final u = data['user'] as Map? ?? {};
    final av = u['avatar'] as Map? ?? {};
    final score = (data['score'] as num?)?.toInt();
    return _Card(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ReviewPage(data: data, anime: anime))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString(), date: _dateLabel(data['createdAt'])),
        const SizedBox(height: 10),
        _TranslatedText(text: '${data['summary'] ?? 'Ulasan'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (score != null) _Chip('Skor ${score}/100'),
          _Chip('${_likedCount(data)} dari ${data['ratingAmount'] ?? 0} pengguna menyukai ulasan ini'),
        ]),
      ]),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.data, required this.anime});
  final Map<String, dynamic> data;
  final String anime;
  @override
  Widget build(BuildContext context) {
    final user = data['user'] as Map? ?? {};
    final avatar = user['avatar'] as Map? ?? {};
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ThreadPage(data: data, anime: anime))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
            child: Row(children: [
              CircleAvatar(radius: 13, backgroundImage: _anilistAvatar(avatar['large']), child: avatar['large'] == null ? const Icon(Icons.forum_outlined, size: 14) : null),
              const SizedBox(width: 8),
              Expanded(child: Text('Anime discussion  ·  ${user['name'] ?? 'AniList user'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
              Text(_dateLabel(data['createdAt']), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['title'] ?? 'Utas tanpa judul'}', style: const TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w800)),
              if ((data['body'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(data['body'].toString().replaceAll(RegExp(r'[#>*_]'), '').replaceAll(RegExp(r'\\s+'), ' '), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, height: 1.35)),
              ],
            ]),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.hairline))),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              _threadAction(Icons.arrow_upward_rounded, '${data['likeCount'] ?? 0}'),
              const SizedBox(width: 17),
              _threadAction(Icons.mode_comment_outlined, '${data['replyCount'] ?? 0} komentar'),
              const Spacer(),
              _threadAction(Icons.visibility_outlined, '${data['viewCount'] ?? 0}'),
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget _threadAction(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(icon, size: 16, color: AppColors.textSecondary),
  const SizedBox(width: 5),
  Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
]);

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.data, required this.anime});
  final Map<String, dynamic> data;
  final String anime;

  @override
  Widget build(BuildContext context) {
    final u = data['user'] as Map? ?? {};
    final av = u['avatar'] as Map? ?? {};
    final media = data['media'] as Map?;
    final banner = media?['bannerImage']?.toString();
    final score = (data['score'] as num?)?.toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('Ulasan')),
      body: SelectionArea(child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (banner != null && banner.isNotEmpty)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: banner,
                    httpHeaders: _anilistImageHeaders(banner),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.bg.withValues(alpha: .94)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Text(
                      anime,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString(), date: _dateLabel(data['createdAt'])),
                const SizedBox(height: 14),
                _TranslatedText(text: '${data['summary'] ?? 'Ulasan'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (score != null) _Chip('Skor reviewer: ${score}/100'),
                  _Chip('${_likedCount(data)} dari ${data['ratingAmount'] ?? 0} pengguna menyukai ulasan ini'),
                ]),
                const SizedBox(height: 20),
                _TranslatedPost(text: '${data['body'] ?? ''}'),
              ],
            ),
          ),
        ],
      )),
    );
  }
}


/// Threads whose AniList title explicitly references the active episode.
/// Hidden when AniList has no matching discussion.
class EpisodeThreadsSection extends StatefulWidget {
  const EpisodeThreadsSection({super.key, required this.showTitle, required this.episodeNumber, this.malId});
  final String showTitle;
  final String episodeNumber;
  final int? malId;

  @override
  State<EpisodeThreadsSection> createState() => _EpisodeThreadsSectionState();
}

class _EpisodeThreadsSectionState extends State<EpisodeThreadsSection> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final api = sl<AniListService>().api;
    final mediaId = await api.communityMediaId(
      anilistId: null,
      malId: widget.malId,
      title: widget.showTitle,
    );
    if (mediaId == null) return const [];
    final parsedNumber = int.tryParse(
      widget.episodeNumber.trim().replaceFirst(RegExp(r'\.0$'), ''),
    );
    if (parsedNumber == null) return const [];
    final padded = parsedNumber.toString().padLeft(2, '0');
    final queries = <String>{
      'Episode $parsedNumber',
      'Episode $padded',
      'Ep $parsedNumber',
      'Ep $padded',
    };
    final found = <int, Map<String, dynamic>>{};
    for (final query in queries) {
      final rows = await api.fetchThreads(mediaId, search: query);
      for (final row in rows) {
        final id = (row['id'] as num?)?.toInt();
        if (id != null) found[id] = row;
      }
    }
    final pattern = RegExp(
      r'(^|[^a-z0-9])(?:episode|ep)\s*0*' +
          parsedNumber.toString() +
          r'([^0-9]|$)',
      caseSensitive: false,
    );
    return found.values
        .where((row) => pattern.hasMatch('${row['title'] ?? ''}'))
        .toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Diskusi episode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ThreadCard(data: row, anime: widget.showTitle),
            ),
        ]),
      );
    },
  );
}

class _ThreadPage extends StatefulWidget {
  const _ThreadPage({required this.data, required this.anime});
  final Map<String, dynamic> data;
  final String anime;
  @override
  State<_ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<_ThreadPage> {
  late Future<Map<String, dynamic>?> threadFuture;
  final TextEditingController replyController = TextEditingController();
  bool rawMode = false;

  @override
  void initState() {
    super.initState();
    final id = (widget.data['id'] as num?)?.toInt();
    threadFuture = id == null ? Future.value(null) : sl<AniListService>().api.fetchThread(id);
  }

  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = (widget.data['id'] as num?)?.toInt();
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18191B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Diskusi anime', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          Text(widget.anime, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B9DA3))),
        ]),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF24262B),
            onSelected: (value) => setState(() => rawMode = value == 'raw'),
            itemBuilder: (_) => [
              PopupMenuItem(value: rawMode ? 'markdown' : 'raw',
                child: Text(rawMode ? 'Tampilkan Markdown' : 'Lihat teks raw')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: id == null
        ? const Center(child: Text('Utas tidak tersedia.'))
        : FutureBuilder<Map<String, dynamic>?>(
          future: threadFuture,
          builder: (context, snapshot) {
            final post = snapshot.data ?? widget.data;
            final user = post['user'] as Map? ?? {};
            final avatar = user['avatar'] as Map? ?? {};
            return Column(children: [
              Expanded(child: SelectionArea(child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    color: const Color(0xFF18191B),
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 17,
                          backgroundImage: _anilistAvatar(avatar['large']),
                          child: avatar['large'] == null ? const Icon(Icons.person, size: 18) : null),
                        const SizedBox(width: 9),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${user['name'] ?? 'AniList user'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('Diposting ${_dateLabel(post['createdAt'])}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF96989F))),
                        ])),
                        const Icon(Icons.public, size: 16, color: Color(0xFF96989F)),
                      ]),
                      const SizedBox(height: 15),
                      Text('${post['title'] ?? ''}',
                        style: const TextStyle(fontSize: 20, height: 1.28, fontWeight: FontWeight.w800, color: Color(0xFFF1F1F2))),
                      if ((post['body'] ?? '').toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(minHeight: 2),
                        rawMode ? SelectableText('${post['body'] ?? ''}', style: const TextStyle(color: Color(0xFFE5E5E7), height: 1.5)) : _TranslatedPost(text: '${post['body'] ?? ''}'),
                      ],
                      const SizedBox(height: 17),
                      Row(children: [
                        _LoveButton(commentId: id, isThread: true, count: (post['likeCount'] as num?)?.toInt() ?? 0, initiallyLiked: post['isLiked'] == true),
                        const SizedBox(width: 9),
                        _redditAction(Icons.mode_comment_outlined, '${post['replyCount'] ?? 0}'),
                        const Spacer(),
                        IconButton(onPressed: () {}, visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.share_outlined, size: 19, color: Color(0xFFB7B9BF))),
                      ]),
                    ]),
                  ),
                  const Divider(height: 8, thickness: 8, color: Color(0xFF090A0B)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 7),
                    child: Row(children: [
                      const Text('Komentar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 7),
                      Text('${post['replyCount'] ?? 0}', style: const TextStyle(color: Color(0xFF92949A), fontSize: 12)),
                      const Spacer(),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
                    child: _ThreadComments(threadId: id,
                      expectedCount: (post['replyCount'] as num?)?.toInt() ?? 0, rawMode: rawMode),
                  ),
                ],
              ))),
              SafeArea(top: false, child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF18191B),
                  border: Border(top: BorderSide(color: Color(0xFF303136))),
                ),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                child: Row(children: [
                  _CurrentProfileAvatar(),
                  const SizedBox(width: 9),
                  Expanded(child: TextField(
                    controller: replyController,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ikut bergabung dalam percakapan',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF92949A)),
                      filled: true,
                      fillColor: const Color(0xFF292B30),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    ),
                  )),
                  const SizedBox(width: 8),
                  const Icon(Icons.image_outlined, color: Color(0xFFB7B9BF), size: 22),
                ]),
              )),
            ]);
          },
        ),
    );
  }
}

Widget _redditAction(IconData icon, String label) => Container(
  decoration: BoxDecoration(color: const Color(0xFF292B30), borderRadius: BorderRadius.circular(22)),
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: const Color(0xFFB8BAC0)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE0E1E4))),
  ]),
);

Widget _postPill(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(icon, size: 15, color: AppColors.textSecondary),
  const SizedBox(width: 5),
  Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
]);

class _ThreadComments extends StatefulWidget {
  const _ThreadComments({required this.threadId, required this.expectedCount, this.rawMode = false});
  final int threadId, expectedCount;
  final bool rawMode;
  @override
  State<_ThreadComments> createState() => _ThreadCommentsState();
}

class _ThreadCommentsState extends State<_ThreadComments> {
  String sort = 'ID_DESC';
  late Future<List<Map<String, dynamic>>> commentsFuture;

  @override
  void initState() {
    super.initState();
    commentsFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      sl<AniListService>().api.fetchThreadComments(widget.threadId, sort: sort);

  void _changeSort(String value) {
    if (value == sort) return;
    setState(() {
      sort = value;
      commentsFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 9),
        child: Row(children: [
          const Text('Urutkan:', style: TextStyle(fontSize: 12, color: Color(0xFF96989F))),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: sort,
            isDense: true,
            dropdownColor: const Color(0xFF24262B),
            style: const TextStyle(fontSize: 12, color: Color(0xFFE5E5E7), fontWeight: FontWeight.w700),
            items: const [
              DropdownMenuItem(value: 'ID_DESC', child: Text('Terbaru')),
              DropdownMenuItem(value: 'ID', child: Text('Terlama')),

            ],
            onChanged: (value) { if (value != null) _changeSort(value); },
          )),
        ]),
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: commentsFuture,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
          }
          final rows = s.data ?? const [];
          if (rows.isEmpty) {
            return Text(s.hasError ? 'Komentar gagal dimuat.' : widget.expectedCount > 0 ? 'AniList belum mengirim komentar untuk utas ini.' : 'Belum ada komentar.');
          }
          return Column(children: [
            for (var i = 0; i < rows.length; i++)
              _Comment(data: rows[i], rawMode: widget.rawMode, isLast: i == rows.length - 1),
          ]);
        },
      ),
    ],
  );
}

/// AniList returns `childComments` as a JSON-encoded string, not as a
/// GraphQL list. Accept both forms so nested replies are not silently lost.
List<Map<String, dynamic>> _commentChildren(Object? raw) {
  Object? value = raw;
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    try {
      value = jsonDecode(value);
    } catch (_) {
      return const [];
    }
  }
  if (value is Map) {
    // A reply node is itself a comment; keep it so its own childComments
    // can be rendered recursively by _Comment.
    if (value.containsKey('id') || value.containsKey('comment')) {
      return [Map<String, dynamic>.from(value)];
    }
    final nested = value['childComments'] ?? value['children'] ?? value['replies'];
    if (nested != null) return _commentChildren(nested);
    return const [];
  }
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

class _Comment extends StatelessWidget {
  const _Comment({
    required this.data,
    this.depth = 0,
    this.rawMode = false,
    this.isLast = false,
    this.isThread = false,
  });

  final Map<String, dynamic> data;
  final int depth;
  final bool rawMode;
  final bool isLast;
  final bool isThread;

  @override
  Widget build(BuildContext context) {
    final user = data['user'] as Map? ?? {};
    final avatar = user['avatar'] as Map? ?? {};
    final children = _commentChildren(data['childComments']);
    final id = (data['id'] as num?)?.toInt();

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 3, bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          if (depth > 0)
            SizedBox(
              width: 17,
              child: CustomPaint(
                painter: _CommentThreadLinePainter(isLast: isLast),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundImage: _anilistAvatar(avatar['large']),
                      child: avatar['large'] == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${user['name'] ?? 'AniList user'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _dateLabel(data['createdAt']),
                                style: const TextStyle(
                                  color: Color(0xFF85878E),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          rawMode
                              ? SelectableText(
                                  '${data['comment'] ?? ''}',
                                  style: const TextStyle(
                                    color: Color(0xFFE5E5E7),
                                    height: 1.5,
                                  ),
                                )
                              : _TranslatedMarkdown(
                                  text: '${data['comment'] ?? ''}',
                                ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _LoveButton(
                                commentId: id,
                                count: (data['likeCount'] as num?)?.toInt() ?? 0,
                                initiallyLiked: data['isLiked'] == true,
                                isThread: isThread,
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Balas',
                                style: TextStyle(
                                  color: Color(0xFFB5B7BD),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.more_horiz,
                                size: 17,
                                color: Color(0xFF96989F),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                        ],
                      ),
                    ),
                  ],
                ),
                if (children.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Column(
                      children: [
                        for (var i = 0; i < children.length; i++)
                          _Comment(
                            data: children[i],
                            depth: depth + 1,
                            rawMode: rawMode,
                            isLast: i == children.length - 1,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// Draws a continuous vertical rail and a short branch into each reply,
/// matching the familiar threaded-comment layout.
class _CommentThreadLinePainter extends CustomPainter {
  const _CommentThreadLinePainter({required this.isLast});
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF555860)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const x = 7.0;
    const branchY = 16.0;
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x, branchY - 4)
      ..quadraticBezierTo(x, branchY, x + 4, branchY)
      ..lineTo(size.width, branchY);
    if (!isLast) path.lineTo(size.width, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CommentThreadLinePainter oldDelegate) =>
      oldDelegate.isLast != isLast;
}

class _CurrentProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = sl<ViewerProfileStore>().activeProfile;
    final accountPhoto = sl.isRegistered<AuthCubit>()
        ? sl<AuthCubit>().state.avatarUrl
        : null;
    final url = profilePhotoForFace(profile: profile, accountPhotoUrl: accountPhoto);
    return ProfileAvatarFace(
      profile: profile,
      photoUrl: url,
      iconSize: 18,
      photoDiameter: 32,
    );
  }
}

class _LoveButton extends StatefulWidget {
  const _LoveButton({required this.commentId, required this.count, required this.initiallyLiked, this.isThread = false});
  final bool isThread;
  final int? commentId;
  final int count;
  final bool initiallyLiked;
  @override
  State<_LoveButton> createState() => _LoveButtonState();
}
class _LoveButtonState extends State<_LoveButton> {
  late bool liked;
  late int count;
  bool busy = false;
  @override
  void initState() { super.initState(); liked = widget.initiallyLiked; count = widget.count; }
  @override
  void didUpdateWidget(covariant _LoveButton old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count || old.initiallyLiked != widget.initiallyLiked) {
      liked = widget.initiallyLiked; count = widget.count;
    }
  }
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: busy || widget.commentId == null ? null : () async {
      setState(() { busy = true; liked = !liked; count += liked ? 1 : -1; });
      final ok = widget.isThread
          ? await sl<AniListService>().api.toggleThreadLike(widget.commentId!)
          : await sl<AniListService>().api.toggleThreadCommentLike(widget.commentId!);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (!ok) { liked = widget.initiallyLiked; count = widget.count; }
      });
    },
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(liked ? Icons.favorite : Icons.favorite_border, size: 16, color: liked ? Colors.pinkAccent : AppColors.textSecondary),
        const SizedBox(width: 5),
        Text('$count suka', style: TextStyle(fontSize: 12, color: liked ? Colors.pinkAccent : AppColors.textSecondary)),
      ]),
    ),
  );
}

class _TranslatedText extends StatefulWidget {
  const _TranslatedText({required this.text, this.style});
  final String text;
  final TextStyle? style;
  @override
  State<_TranslatedText> createState() => _TranslatedTextState();
}
class _TranslatedTextState extends State<_TranslatedText> {
  String? translated;
  @override
  void initState() { super.initState(); _go(); }
  @override
  void didUpdateWidget(covariant _TranslatedText old) { super.didUpdateWidget(old); if (old.text != widget.text) _go(); }
  Future<void> _go() async {
    final value = await SynopsisTranslator.instance.translateTextToIndonesian(widget.text);
    if (mounted) setState(() => translated = value);
  }
  @override
  Widget build(BuildContext context) => Text(translated ?? widget.text, style: widget.style);
}

// Protect Markdown syntax, embedded media, URLs and link destinations while
// translating only readable prose. This prevents X image links from being
// corrupted by machine translation.
Future<String?> _translateMarkdownSafely(String source) async {
  final protected = <String>[];
  final pattern = RegExp(
    r'((?:˜˜˜|~~~center[ \t]*\n|~~~)|```[\s\S]*?```|`[^`\n]+`|!?\[[^\]]*\]\(https?://[^)]+\)|img(?:\d{1,4}|\d{1,3}%)?\(https?://[^)]+\)|youtube\([^)]+\)|webm\(https?://[^)]+\)|https?://[^\s)]+|<[^>]+>)',
    caseSensitive: false,
  );
  final masked = source.replaceAllMapped(pattern, (m) {
    final key = 'ZXQKEEP${protected.length}QXZ';
    protected.add(m[0]!);
    return key;
  });
  final translated = await SynopsisTranslator.instance.translateTextToIndonesian(masked);
  if (translated == null) return null;
  var restored = translated;
  for (var i = 0; i < protected.length; i++) {
    restored = restored.replaceAll('ZXQKEEP${i}QXZ', protected[i]);
  }
  // If the translator altered a placeholder, return the untouched source.
  if (RegExp(r'ZXQKEEP\d+QXZ').hasMatch(restored)) return source;
  return restored;
}

class _TranslatedPost extends StatefulWidget {
  const _TranslatedPost({required this.text, this.showOriginalToggle = false});
  final String text;
  final bool showOriginalToggle;
  @override
  State<_TranslatedPost> createState() => _TranslatedPostState();
}
class _TranslatedPostState extends State<_TranslatedPost> {
  String? translated;
  bool showOriginal = false;
  @override
  void initState() { super.initState(); _go(); }
  @override
  void didUpdateWidget(covariant _TranslatedPost old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) { translated = null; showOriginal = false; _go(); }
  }
  Future<void> _go() async {
    final value = await _translateMarkdownSafely(widget.text);
    if (!mounted) return;
    setState(() => translated = value);
  }
  @override
  Widget build(BuildContext context) {
    final content = showOriginal ? widget.text : (translated ?? widget.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AniListMarkdown(data: content),
      if (widget.showOriginalToggle && translated != null && translated != widget.text) ...[
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: TextButton(
          onPressed: () => setState(() => showOriginal = !showOriginal),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(showOriginal ? 'Lihat terjemahan' : 'Lihat asli',
            style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
        )),
      ],
    ]);
  }
}

class _TranslatedMarkdown extends StatefulWidget {
  const _TranslatedMarkdown({required this.text});
  final String text;
  @override
  State<_TranslatedMarkdown> createState() => _TranslatedMarkdownState();
}
class _TranslatedMarkdownState extends State<_TranslatedMarkdown> {
  String? translated;
  @override
  void initState() { super.initState(); _go(); }
  @override
  void didUpdateWidget(covariant _TranslatedMarkdown old) { super.didUpdateWidget(old); if (old.text != widget.text) _go(); }
  Future<void> _go() async {
    final value = await _translateMarkdownSafely(widget.text);
    if (mounted) setState(() => translated = value);
  }
  @override
  Widget build(BuildContext context) => AniListMarkdown(data: translated ?? widget.text);
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface2, borderRadius: BorderRadius.circular(14),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(14), child: child)),
  );
}

class _User extends StatelessWidget {
  const _User({required this.name, this.avatar, this.date});
  final String name;
  final String? avatar, date;
  @override
  Widget build(BuildContext context) => Row(children: [
    CircleAvatar(radius: 16, backgroundImage: avatar == null || avatar!.isEmpty ? null : _anilistAvatar(avatar!), child: avatar == null || avatar!.isEmpty ? const Icon(Icons.person, size: 18) : null),
    const SizedBox(width: 9),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (date != null && date!.isNotEmpty) Text(date!, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ])),
  ]);
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({this.views, this.likes, this.comments});
  final Object? views, likes, comments;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 6, children: [
    _stat(Icons.visibility_outlined, '${views ?? 0} tayangan'),
    _stat(Icons.favorite_border, '${likes ?? 0} suka'),
    _stat(Icons.mode_comment_outlined, '${comments ?? 0} komentar'),
  ]);
  Widget _stat(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 15, color: AppColors.textSecondary),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ]);
}
