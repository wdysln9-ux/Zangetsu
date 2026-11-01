import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/anilist/anilist_service.dart';
import '../../core/di/injector.dart';
import '../../core/metadata/synopsis_translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/anilist_markdown.dart';

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

int _likedCount(Map data) {
  final rating = (data['rating'] as num?)?.toInt() ?? 0;
  final amount = (data['ratingAmount'] as num?)?.toInt() ?? 0;
  return ((rating.clamp(0, 100) * amount) / 100).round();
}

String _dateLabel(Object? raw) {
  final seconds = (raw as num?)?.toInt();
  if (seconds == null || seconds <= 0) return '';
  return DateFormat('d MMM yyyy', 'id').format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));
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
    final u = data['user'] as Map? ?? {};
    final av = u['avatar'] as Map? ?? {};
    return _Card(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ThreadPage(data: data, anime: anime))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString(), date: _dateLabel(data['createdAt'])),
        const SizedBox(height: 9),
        _TranslatedText(text: '${data['title'] ?? 'Utas tanpa judul'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _Stats(views: data['viewCount'], likes: data['likeCount'], comments: data['replyCount']),
      ]),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.data, required this.anime});
  final Map<String, dynamic> data;
  final String anime;
  @override
  Widget build(BuildContext context) {
    final u = data['user'] as Map? ?? {};
    final av = u['avatar'] as Map? ?? {};
    final score = (data['score'] as num?)?.toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('Ulasan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(anime, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 14),
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
      ]),
    );
  }
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
  @override
  void initState() {
    super.initState();
    final id = (widget.data['id'] as num?)?.toInt();
    threadFuture = id == null ? Future.value(null) : sl<AniListService>().api.fetchThread(id);
  }
  @override
  Widget build(BuildContext context) {
    final id = (widget.data['id'] as num?)?.toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('Utas')),
      body: id == null ? const Center(child: Text('Utas tidak tersedia.')) :
        FutureBuilder<Map<String, dynamic>?>(
          future: threadFuture,
          builder: (context, s) {
            final d = s.data ?? widget.data;
            final u = d['user'] as Map? ?? {};
            final av = u['avatar'] as Map? ?? {};
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                Text(widget.anime, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                // Reddit-inspired post header: author metadata above a full-width post.
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString(), date: _dateLabel(d['createdAt'])),
                  const SizedBox(height: 14),
                  _TranslatedText(text: '${d['title'] ?? ''}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (s.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
                  _TranslatedPost(text: '${d['body'] ?? ''}'),
                  const SizedBox(height: 14),
                  _Stats(views: d['viewCount'], likes: d['likeCount'], comments: d['replyCount']),
                ])),
                const SizedBox(height: 22),
                Row(children: [
                  const Text('Komentar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 7),
                  Text('${d['replyCount'] ?? 0}', style: TextStyle(color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 12),
                _ThreadComments(threadId: id, expectedCount: (d['replyCount'] as num?)?.toInt() ?? 0),
              ],
            );
          },
        ),
    );
  }
}

class _ThreadComments extends StatelessWidget {
  const _ThreadComments({required this.threadId, required this.expectedCount});
  final int threadId, expectedCount;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: sl<AniListService>().api.fetchThreadComments(threadId),
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
      final comments = s.data ?? const [];
      if (comments.isEmpty) {
        return Text(s.hasError ? 'Komentar gagal dimuat.' : expectedCount > 0 ? 'AniList belum mengirim komentar untuk utas ini.' : 'Belum ada komentar.');
      }
      return Column(children: [
        for (final comment in comments) _Comment(data: comment),
      ]);
    },
  );
}

class _Comment extends StatelessWidget {
  const _Comment({required this.data, this.depth = 0});
  final Map<String, dynamic> data;
  final int depth;
  @override
  Widget build(BuildContext context) {
    final u = data['user'] as Map? ?? {};
    final av = u['avatar'] as Map? ?? {};
    final children = data['childComments'] is List ? data['childComments'] as List : const [];
    final id = (data['id'] as num?)?.toInt();
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 15, bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (depth > 0) Container(width: 2, margin: const EdgeInsets.only(right: 10), color: AppColors.textSecondary.withValues(alpha: .25)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 15, backgroundImage: av['large'] == null ? null : NetworkImage('${av['large']}'), child: av['large'] == null ? const Icon(Icons.person, size: 16) : null),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text('${u['name'] ?? 'AniList user'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  const SizedBox(width: 7),
                  Text(_dateLabel(data['createdAt']), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ]),
                const SizedBox(height: 7),
                _TranslatedMarkdown(text: '${data['comment'] ?? ''}'),
                const SizedBox(height: 7),
                Row(children: [
                  _LoveButton(commentId: id, count: (data['likeCount'] as num?)?.toInt() ?? 0, initiallyLiked: data['isLiked'] == true),
                  const SizedBox(width: 18),
                  TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.reply_rounded, size: 16),
                    label: const Text('Balas'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, foregroundColor: AppColors.textSecondary),
                  ),
                ]),
              ])),
            ]),
          ),
          if (children.isNotEmpty)
            for (final child in children)
              if (child is Map) _Comment(data: Map<String, dynamic>.from(child), depth: depth + 1),
        ])),
      ]),
    );
  }
}

class _LoveButton extends StatefulWidget {
  const _LoveButton({required this.commentId, required this.count, required this.initiallyLiked});
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
      final ok = await sl<AniListService>().api.toggleThreadCommentLike(widget.commentId!);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (!ok) { liked = !liked; count += liked ? -1 : 1; }
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
    r'(```[\s\S]*?```|`[^`\n]+`|!?\[[^\]]*\]\(https?://[^)]+\)|img(?:\d{1,4}|\d{1,3}%)?\(https?://[^)]+\)|youtube\([^)]+\)|webm\(https?://[^)]+\)|https?://[^\s)]+|<[^>]+>)',
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
  const _TranslatedPost({required this.text});
  final String text;
  @override
  State<_TranslatedPost> createState() => _TranslatedPostState();
}
class _TranslatedPostState extends State<_TranslatedPost> {
  String? translated;
  @override
  void initState() { super.initState(); _go(); }
  @override
  void didUpdateWidget(covariant _TranslatedPost old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) { translated = null; _go(); }
  }
  Future<void> _go() async {
    final value = await _translateMarkdownSafely(widget.text);
    if (!mounted) return;
    setState(() => translated = value);
  }
  @override
  Widget build(BuildContext context) => AniListMarkdown(data: translated ?? widget.text);
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
    CircleAvatar(radius: 16, backgroundImage: avatar == null || avatar!.isEmpty ? null : NetworkImage(avatar!), child: avatar == null || avatar!.isEmpty ? const Icon(Icons.person, size: 18) : null),
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
