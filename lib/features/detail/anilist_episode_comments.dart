import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Episode discussions sourced from MyAnimeList through the Jikan API.
/// MAL exposes episode forum topics (including the first-post preview and
/// reply count); individual replies remain on the original MAL topic page.
class AniListEpisodeComments extends StatefulWidget {
  const AniListEpisodeComments({
    super.key,
    required this.title,
    required this.episodeNumber,
    this.malId,
  });

  final String title;
  final int? malId;
  final String episodeNumber;

  @override
  State<AniListEpisodeComments> createState() => _AniListEpisodeCommentsState();
}

class _AniListEpisodeCommentsState extends State<AniListEpisodeComments> {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      headers: const {'Accept': 'application/json'},
    ),
  );

  late Future<List<Map<String, dynamic>>> _future = _load();
  int _sort = 0;

  @override
  void didUpdateWidget(covariant AniListEpisodeComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.malId != widget.malId ||
        oldWidget.episodeNumber != widget.episodeNumber) {
      _future = _load();
    }
  }

  int? get _episode => int.tryParse(
        widget.episodeNumber.replaceAll(RegExp(r'[^0-9]'), ''),
      );

  Future<List<Map<String, dynamic>>> _load() async {
    final id = widget.malId;
    if (id == null || id <= 0) return const [];

    try {
      final response = await _dio.get<dynamic>(
        'https://api.jikan.moe/v4/anime/$id/forum',
        queryParameters: const {'filter': 'episode'},
        options: Options(
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      final payload = response.data;
      final data = payload is Map ? payload['data'] : null;
      if (data is! List) return const [];

      final episode = _episode;
      final topics = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((topic) => _matchesEpisode(topic, episode))
          .toList();

      topics.sort((a, b) {
        if (_sort == 0) {
          final ar = (a['replies'] as num?)?.toInt() ?? 0;
          final br = (b['replies'] as num?)?.toInt() ?? 0;
          return br.compareTo(ar);
        }
        final ad = DateTime.tryParse((a['date'] ?? '').toString());
        final bd = DateTime.tryParse((b['date'] ?? '').toString());
        return _sort == 1
            ? (bd ?? DateTime(0)).compareTo(ad ?? DateTime(0))
            : (ad ?? DateTime(0)).compareTo(bd ?? DateTime(0));
      });
      return topics;
    } on DioException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  bool _matchesEpisode(Map<String, dynamic> topic, int? episode) {
    if (episode == null) return false;
    final title = (topic['title'] ?? '').toString();
    final pattern = RegExp(
      r'\\b(?:episode|ep\\.?|#)\\s*0*' +
          episode.toString() +
          r'\\b|\\b0*' +
          episode.toString() +
          r'(?:st|nd|rd|th)\\s+episode\\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(title);
  }

  String _author(Map<String, dynamic> topic) {
    final author = topic['author'];
    if (author is Map) return (author['name'] ?? 'Pengguna MAL').toString();
    return 'Pengguna MAL';
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _openTopic(String? rawUrl) async {
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null ||
        uri.host != 'myanimelist.net' ||
        !await canLaunchUrl(uri)) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final topics = snapshot.data ?? const <Map<String, dynamic>>[];
        if (topics.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined,
                      size: 34, color: Colors.white38),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada diskusi episode ini di forum MAL.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Muat ulang'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Diskusi MyAnimeList',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                DropdownButton<int>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Terbanyak dibalas')),
                    DropdownMenuItem(value: 1, child: Text('Terbaru')),
                    DropdownMenuItem(value: 2, child: Text('Terlama')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final topic in topics) _topicCard(topic),
          ],
        );
      },
    );
  }

  Widget _topicCard(Map<String, dynamic> topic) {
    final title = (topic['title'] ?? 'Diskusi episode').toString();
    final intro = (topic['intro'] ?? '').toString().trim();
    final replies = (topic['replies'] as num?)?.toInt() ?? 0;
    final author = _author(topic);
    final date = _date(topic['date']);
    final url = (topic['url'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF171C27),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF292F3B)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openTopic(url),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFFF1F2F5),
                ),
              ),
              if (intro.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  intro.replaceAll(RegExp(r'<[^>]*>'), ' ').trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB7BFCC),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 15, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(date,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  const SizedBox(width: 10),
                  const Icon(Icons.mode_comment_outlined,
                      size: 14, color: Color(0xFFF47521)),
                  const SizedBox(width: 4),
                  Text('$replies balasan',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 5),
                  const Icon(Icons.open_in_new,
                      size: 13, color: Colors.white54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
