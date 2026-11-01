import 'package:flutter/material.dart';
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
        _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString()),
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
        _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString()),
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
        _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString()),
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

class _ThreadPage extends StatelessWidget {
  const _ThreadPage({required this.data, required this.anime});
  final Map<String, dynamic> data;
  final String anime;

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] as num?)?.toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('Utas')),
      body: id == null
        ? const Center(child: Text('Utas tidak tersedia.'))
        : FutureBuilder<Map<String, dynamic>?>(
            future: sl<AniListService>().api.fetchThread(id),
            builder: (context, s) {
              final d = s.data ?? data;
              final u = d['user'] as Map? ?? {};
              final av = u['avatar'] as Map? ?? {};
              return ListView(padding: const EdgeInsets.all(14), children: [
                Text(anime, style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString()),
                  const SizedBox(height: 12),
                  _TranslatedText(text: '${d['title'] ?? ''}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (s.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
                  _TranslatedPost(text: '${d['body'] ?? ''}'),
                  const SizedBox(height: 14),
                  _Stats(views: d['viewCount'], likes: d['likeCount'], comments: d['replyCount']),
                ])),
                const SizedBox(height: 18),
                Text('Komentar (${d['replyCount'] ?? 0})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _ThreadComments(threadId: id, expectedCount: (d['replyCount'] as num?)?.toInt() ?? 0),
              ]);
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
      if (s.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
      final comments = s.data ?? const [];
      if (comments.isEmpty) {
        return Text(s.hasError ? 'Komentar gagal dimuat.' : expectedCount > 0 ? 'Komentar belum berhasil dimuat.' : 'Belum ada komentar.');
      }
      return Column(children: [
        for (final comment in comments) _Comment(data: comment),
      ]);
    },
  );
}

class _Comment extends StatelessWidget {
  const _Comment({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final u = data['user'] as Map? ?? {};
    final av = u['avatar'] as Map? ?? {};
    final children = data['childComments'] is List ? data['childComments'] as List : const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _User(name: '${u['name'] ?? 'AniList user'}', avatar: av['large']?.toString()),
        const SizedBox(height: 8),
        _TranslatedMarkdown(text: '${data['comment'] ?? ''}'),
        const SizedBox(height: 8),
        Text('♡ ${data['likeCount'] ?? 0} suka', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        if (children.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final child in children) if (child is Map) Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: _Comment(data: Map<String, dynamic>.from(child)),
          ),
        ],
      ])),
    );
  }
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

class _TranslatedPost extends StatefulWidget {
  const _TranslatedPost({required this.text});
  final String text;
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
    final value = await SynopsisTranslator.instance.translateTextToIndonesian(widget.text);
    if (!mounted) return;
    setState(() => translated = value == null ? null : _makeCasual(value));
  }
  String _makeCasual(String value) => value
      .replaceAll(RegExp(r'\bAnda\b', caseSensitive: false), 'kamu')
      .replaceAll(RegExp(r'\bAnda\b', caseSensitive: false), 'kamu')
      .replaceAll(RegExp(r'\bsaya\b', caseSensitive: false), 'aku')
      .replaceAll(RegExp(r'\btidak\b', caseSensitive: false), 'nggak')
      .replaceAll(RegExp(r'\b tetapi \b', caseSensitive: false), ' tapi ')
      .replaceAll(RegExp(r'\b sangat \b', caseSensitive: false), ' banget ');

  @override
  Widget build(BuildContext context) {
    final ready = translated != null && translated!.isNotEmpty && translated != widget.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (ready) Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Expanded(child: Text('Diterjemahkan dari Inggris', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          TextButton(
            onPressed: () => setState(() => showOriginal = !showOriginal),
            child: Text(showOriginal ? 'Tampilkan terjemahan' : 'Tampilkan yang asli'),
          ),
        ]),
      ),
      AniListMarkdown(data: showOriginal ? widget.text : translated ?? widget.text),
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
    final value = await SynopsisTranslator.instance.translateTextToIndonesian(widget.text);
    if (mounted) setState(() => translated = value == null ? null : value
      .replaceAll(RegExp(r'\bAnda\b', caseSensitive: false), 'kamu')
      .replaceAll(RegExp(r'\bsaya\b', caseSensitive: false), 'aku')
      .replaceAll(RegExp(r'\btidak\b', caseSensitive: false), 'nggak'));
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
  const _User({required this.name, this.avatar});
  final String name;
  final String? avatar;
  @override
  Widget build(BuildContext context) => Row(children: [
    CircleAvatar(radius: 16, backgroundImage: avatar == null || avatar!.isEmpty ? null : NetworkImage(avatar!), child: avatar == null || avatar!.isEmpty ? const Icon(Icons.person, size: 18) : null),
    const SizedBox(width: 9),
    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
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
