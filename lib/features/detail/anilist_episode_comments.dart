import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AniListEpisodeComments extends StatefulWidget {
  const AniListEpisodeComments({super.key, required this.title, required this.episodeNumber, this.malId});
  final String title;
  final int? malId;
  final String episodeNumber;
  @override
  State<AniListEpisodeComments> createState() => _AniListEpisodeCommentsState();
}

class _AniListEpisodeCommentsState extends State<AniListEpisodeComments> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  int _sort = 0;

  Future<List<Map<String, dynamic>>> _query(String query, Map<String, dynamic> vars) async {
    try {
      final response = await Dio().post('https://graphql.anilist.co',
        data: {'query': query, 'variables': vars},
        options: Options(headers: {'Content-Type': 'application/json'},
          validateStatus: (s) => s != null && s < 500));
      final data = response.data;
      dynamic media;
      if (data is Map) {
        final payload = data['data'];
        if (payload is Map) media = payload['Media'];
      }
      dynamic threads;
      if (media is Map) threads = media['threads'];
      if (threads is List) return threads.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> _load() async {
    const fields = 'id title comments(perPage:50,sort:ID){id comment likeCount createdAt user{id name avatar{large}} childComments{id}}';
    if (widget.malId != null) {
      final found = await _query(
        r'query($idMal:Int){Media(idMal:$idMal,type:ANIME){threads(perPage:50,sort:ID_DESC){' + fields + '}}}',
        {'idMal': widget.malId});
      if (found.isNotEmpty) return found;
    }
    return _query(
      r'query($search:String){Media(search:$search,type:ANIME){threads(perPage:50,sort:ID_DESC){' + fields + '}}}',
      {'search': widget.title});
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> threads) {
    final comments = <Map<String, dynamic>>[];
    for (final thread in threads) {
      final title = (thread['title'] ?? '').toString();
      final number = RegExp(r'\d+(?:\.\d+)?')
          .firstMatch(widget.episodeNumber)
          ?.group(0);
      if (number == null ||
          !RegExp(
            r'(?:episode|ep\.?)[\s:#-]*' +
                RegExp.escape(number) +
                r'(?![\d.])',
            caseSensitive: false,
          ).hasMatch(title)) {
        continue;
      }
      final list = thread['comments'];
      if (list is List) comments.addAll(list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    }
    comments.sort((a, b) {
      final la = (a['likeCount'] as num?)?.toInt() ?? 0;
      final lb = (b['likeCount'] as num?)?.toInt() ?? 0;
      final ta = (a['createdAt'] as num?)?.toInt() ?? 0;
      final tb = (b['createdAt'] as num?)?.toInt() ?? 0;
      return _sort == 0 ? lb.compareTo(la) : _sort == 1 ? tb.compareTo(ta) : ta.compareTo(tb);
    });
    return comments;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final comments = _sorted(snapshot.data ?? const []);
      if (comments.isEmpty) return const Center(child: Text('Belum ada komentar untuk episode ini'));
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Text('Komentar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const Spacer(),
          DropdownButton<int>(
            value: _sort, underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Terbaik')),
              DropdownMenuItem(value: 1, child: Text('Terbaru')),
              DropdownMenuItem(value: 2, child: Text('Terlama')),
            ],
            onChanged: (v) { if (v != null) setState(() => _sort = v); },
          ),
        ]),
        const SizedBox(height: 12),
        for (final item in comments) _comment(item),
      ]);
    });

  Widget _comment(Map<String, dynamic> item) {
    final user = item['user'] is Map ? item['user'] as Map : const {};
    final name = (user['name'] ?? 'AniList user').toString();
    final id = (user['id'] as num?)?.toInt();
    final avatar = user['avatar'] is Map ? user['avatar']['large'] as String? : null;
    final replies = item['childComments'] is List ? (item['childComments'] as List).length : 0;
    final body = (item['comment'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), ' ');
    return Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: id == null ? null : () => launchUrl(Uri.https('anilist.co', '/user/$id'), mode: LaunchMode.externalApplication),
          child: Row(children: [
            CircleAvatar(radius: 17, backgroundImage: avatar == null ? null : NetworkImage(avatar),
              child: avatar == null ? const Icon(Icons.person, size: 17) : null),
            const SizedBox(width: 9),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.open_in_new, size: 13),
          ]),
        ),
        const SizedBox(height: 8),
        Text(body),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.favorite_border, size: 15),
          const SizedBox(width: 4),
          Text("${item["likeCount"] ?? 0}"),
          const SizedBox(width: 14),
          const Icon(Icons.mode_comment_outlined, size: 14),
          const SizedBox(width: 4),
          Text('$replies balasan'),
        ]),
        const Divider(height: 22),
      ],
    ));
  }
}
