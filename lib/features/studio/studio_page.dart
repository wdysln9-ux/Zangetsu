import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/ui/states.dart';
import '../detail/open_related.dart';

/// Studio profile and the anime credited to it, loaded from AniList.
class StudioPage extends StatefulWidget {
  const StudioPage({super.key, required this.studioName});

  final String studioName;

  static Route<void> route(String studioName) => MaterialPageRoute<void>(
    builder: (_) => StudioPage(studioName: studioName),
  );

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late Future<Map<String, dynamic>?> _future;
  String? _loadError;
  String _sort = 'START_DATE_DESC';
  final List<Map<String, dynamic>> _extraAnime = [];
  int _nextPage = 2;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    const query = r'''
      query ($search: String, $sort: [MediaSort]) {
        Studio(search: $search) {
          id
          name
          isAnimationStudio
          siteUrl
          favourites
          media(sort: $sort, type: ANIME, isAdult: false, page: 1, perPage: 30) {
            pageInfo { hasNextPage }
            nodes {
              id
              idMal
              title { romaji english }
              coverImage { large }
              averageScore
              episodes
              seasonYear
              format
            }
          }
        }
      }
    ''';
    try {
      final response = await sl<Dio>().post<dynamic>(
        'https://graphql.anilist.co',
        data: {'query': query, 'variables': {'search': widget.studioName, 'sort': [_sort]}},
        options: Options(
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final studio = (data['data'] as Map)['Studio'];
        if (studio is Map) {
          final result = Map<String, dynamic>.from(studio);
          final media = result['media'];
          final pageInfo = media is Map ? media['pageInfo'] : null;
          _nextPage = 2;
          _extraAnime.clear();
          _hasMore = pageInfo is Map && pageInfo['hasNextPage'] == true;
          return result;
        }
      }
      if (data is Map && data['errors'] is List) {
        final errors = data['errors'] as List;
        if (errors.isNotEmpty && errors.first is Map) {
          _loadError = (errors.first as Map)['message']?.toString();
        }
      }
      _loadError ??= 'Studio ini tidak ditemukan di AniList.';
    } on DioException catch (error) {
      _loadError = error.response?.statusCode == 429
          ? 'AniList sedang membatasi permintaan. Coba lagi sebentar.'
          : error.response == null
              ? 'Tidak bisa terhubung ke AniList. Periksa koneksi internet.'
              : 'AniList gagal memuat data (HTTP ${error.response?.statusCode}).';
    } catch (error) {
      _loadError = 'Terjadi kesalahan saat memuat data studio.';
    }
    return null;
  }

  Future<void> _loadMore(int studioId) async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    const query = r'''
      query ($id: Int!, $page: Int!, $sort: [MediaSort]) {
        Studio(id: $id) {
          media(sort: $sort, type: ANIME, isAdult: false, page: $page, perPage: 30) {
            pageInfo { hasNextPage }
            nodes {
              id
              idMal
              title { romaji english }
              coverImage { large }
              averageScore
              episodes
              seasonYear
              format
            }
          }
        }
      }
    ''';
    try {
      final response = await sl<Dio>().post<dynamic>(
        'https://graphql.anilist.co',
        data: {'query': query, 'variables': {'id': studioId, 'page': _nextPage, 'sort': [_sort]}},
        options: Options(
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final data = response.data;
      final root = data is Map && data['data'] is Map ? (data['data'] as Map)['Studio'] : null;
      final media = root is Map ? root['media'] : null;
      final nodes = media is Map ? media['nodes'] : null;
      final pageInfo = media is Map ? media['pageInfo'] : null;
      if (nodes is List && mounted) {
        setState(() {
          _extraAnime.addAll(nodes.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
          _nextPage++;
          _hasMore = pageInfo is Map && pageInfo['hasNextPage'] == true;
        });
      } else if (mounted) {
        setState(() => _hasMore = false);
      }
    } catch (_) {
      // Keep the current anime list if another page fails to load.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _changeSort(String? value) {
    if (value == null || value == _sort) return;
    setState(() {
      _sort = value;
      _extraAnime.clear();
      _nextPage = 2;
      _hasMore = true;
      _loadingMore = false;
      _loadError = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      title: Text(widget.studioName, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final studio = snapshot.data;
        if (studio == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined, size: 42, color: AppColors.textSecondary),
                  const SizedBox(height: 14),
                  Text(
                    'Informasi studio gagal dimuat',
                    textAlign: TextAlign.center,
                    style: AppText.headline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError ?? 'Periksa koneksi lalu coba lagi.',
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _loadError = null;
                      _future = _load();
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        final media = studio['media'] is Map ? (studio['media'] as Map)['nodes'] : null;
        final anime = <Map>[if (media is List) ...media.whereType<Map>(), ..._extraAnime];
        final name = (studio['name'] as String?) ?? widget.studioName;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.movie_creation_outlined, size: 34, color: AppColors.accent),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: AppText.title.copyWith(fontSize: 25)),
                    const SizedBox(height: 6),
                    Text(
                      studio['isAnimationStudio'] == true ? 'Studio animasi' : 'Studio',
                      style: AppText.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Informasi studio', style: AppText.headline.copyWith(fontSize: 16)),
                          const SizedBox(height: 12),
                          _StudioInfoRow(
                            icon: Icons.category_outlined,
                            label: 'Jenis',
                            value: studio['isAnimationStudio'] == true
                                ? 'Studio animasi'
                                : 'Perusahaan produksi',
                          ),
                          const SizedBox(height: 10),
                          _StudioInfoRow(
                            icon: Icons.favorite_border,
                            label: 'Favorit AniList',
                            value: studio['favourites'] is int
                                ? (studio['favourites'] as int).toString()
                                : 'Tidak tersedia',
                          ),
                          const SizedBox(height: 10),
                          _StudioInfoRow(
                            icon: Icons.movie_outlined,
                            label: 'Anime ditampilkan',
                            value: '${anime.length} judul populer',
                          ),
                          if (studio['siteUrl'] is String) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              studio['siteUrl'] as String,
                              style: AppText.caption.copyWith(color: AppColors.accent),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Text('Anime studio', style: AppText.headline)),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sort,
                            dropdownColor: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            style: AppText.caption.copyWith(color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'START_DATE_DESC', child: Text('Newest')),
                              DropdownMenuItem(value: 'POPULARITY_DESC', child: Text('Popularity')),
                              DropdownMenuItem(value: 'START_DATE', child: Text('Oldest')),
                              DropdownMenuItem(value: 'SCORE_DESC', child: Text('Score')),
                            ],
                            onChanged: _changeSort,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      anime.isEmpty ? 'Belum ada anime yang tercatat untuk studio ini.' : '${anime.length} judul dimuat',
                      style: AppText.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (anime.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.49,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = anime[index];
                      final titleData = item['title'] is Map ? item['title'] as Map : const {};
                      final title = (titleData['english'] as String?)?.trim().isNotEmpty == true
                          ? titleData['english'] as String
                          : (titleData['romaji'] as String?) ?? 'Unknown title';
                      final cover = item['coverImage'] is Map ? (item['coverImage'] as Map)['large'] as String? : null;
                      final score = item['averageScore'];
                      final episodes = item['episodes'];
                      final year = item['seasonYear'];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => openRelatedTitle(
                          context,
                          title: title,
                          romaji: titleData['romaji'] as String?,
                          cover: cover,
                          isReading: false,
                          anilistId: item['id'] as int?,
                          malId: item['idMal'] as int?,
                          sourceId: null,
                          fromReadingPage: false,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: cover == null
                                      ? ColoredBox(color: AppColors.surface, child: Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary))
                                      : CachedNetworkImage(
                                          imageUrl: cover,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => ColoredBox(color: AppColors.surface),
                                          errorWidget: (_, __, ___) => ColoredBox(color: AppColors.surface, child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary)),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontSize: 12)),
                            const SizedBox(height: 3),
                            Text(
                              [if (year is int) '$year', if (episodes is int) '$episodes eps', if (score is int && score > 0) '★ ${(score / 10).toStringAsFixed(1)}'].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: anime.length,
                  ),
                ),
              ),
            if (anime.isNotEmpty && (_hasMore || _loadingMore))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _loadingMore ? null : () => _loadMore(studio['id'] as int),
                      icon: _loadingMore
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(_loadingMore ? 'Memuat...' : 'Muat lebih banyak anime'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _StudioInfoRow extends StatelessWidget {
  const _StudioInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.accent),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, style: AppText.body.copyWith(color: AppColors.textSecondary)),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(value, textAlign: TextAlign.end, style: AppText.body),
      ),
    ],
  );
}
