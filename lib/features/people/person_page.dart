import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/ui/anilist_markdown.dart';

import '../../core/di/injector.dart';
import '../../core/metadata/people_service.dart';
import '../detail/open_related.dart';
import '../../core/models/person.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/ui/states.dart';

/// A person page — an anime character or voice actor/staff (AniList), or a
/// movie/TV person (TMDB). Opened from the Detail screen's Cast tab. Metadata
/// only: it never touches a provider except to open a tapped title in the
/// active source (searched by title, like the Relations tab).
class PersonPage extends StatefulWidget {
  const PersonPage({super.key, required this.person, this.sourceId});

  final PersonRef person;

  /// The source to search when a title on this page is tapped. Null → active.
  final String? sourceId;

  static Route<void> route(PersonRef person, {String? sourceId}) =>
      MaterialPageRoute<void>(
        builder: (_) => PersonPage(person: person, sourceId: sourceId),
      );

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  late Future<PersonProfile?> _future;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _future = sl<PeopleService>().load(widget.person);
  }

  /// Open a title from this person's works.
  ///
  /// An author's page is mostly manga, and a voice actor's is mostly anime —
  /// so which source to ask depends on the work, not on where you came from.
  Future<void> _openWork(PersonWork w) => openRelatedTitle(
    context,
    title: w.title,
    romaji: w.romaji,
    cover: w.cover,
    isReading: w.isReading,
    malId: w.malId,
    sourceId: widget.sourceId,
    fromReadingPage: !w.isReading,
  );

  String _displayName(String value) {
    if (widget.person.source != PersonSource.anilistCharacter) return value;
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return value;
    return [parts.last, ...parts.sublist(1, parts.length - 1), parts.first]
        .join(' ');
  }

  void _openRelated(PersonRef ref) {
    Navigator.of(
      context,
    ).push(PersonPage.route(ref, sourceId: widget.sourceId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: widget.person.source == PersonSource.anilistCharacter
            ? null
            : Text(
                _displayName(widget.person.name),
                style: AppText.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      body: FutureBuilder<PersonProfile?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          final p = snap.data;
          if (p == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              message: 'Couldn’t load this profile',
            );
          }
          return _content(p);
        },
      ),
    );
  }

  Widget _content(PersonProfile p) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(p)),
        if (widget.person.source == PersonSource.anilistCharacter &&
            _hasCharacterFacts(p))
          SliverToBoxAdapter(child: _characterFacts(p)),
        if (p.description != null && p.description!.isNotEmpty)
          SliverToBoxAdapter(
            child: _bio(
              widget.person.source == PersonSource.anilistCharacter
                  ? _bioWithoutManualFacts(p.description!)
                  : p.description!,
            ),
          ),
        if (p.related.isNotEmpty)
          SliverToBoxAdapter(child: _relatedRow(p.related)),
        if (p.works.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionLabel(
              widget.person.source == PersonSource.anilistStaff
                  ? 'Roles'
                  : 'Peran',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _workCard(p.works[i]),
                childCount: p.works.length,
              ),
            ),
          ),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _header(PersonProfile p) {
    if (widget.person.source == PersonSource.anilistCharacter) {
      return _characterHeader(p);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 118,
              height: 158,
              child: (p.photo != null && p.photo!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: p.photo!,
                      fit: BoxFit.cover,
                      // 118x158 portrait: decode small, not full photo.
                      memCacheWidth: 354,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, _, _) => const _PortraitFallback(),
                    )
                  : const _PortraitFallback(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(_displayName(p.name), style: AppText.title),
                if (widget.person.source == PersonSource.anilistCharacter &&
                    p.alternateNames.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    p.alternateNames.join(' · '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (p.nativeName != null && p.nativeName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.nativeName!, style: AppText.body),
                ],
                if (widget.person.source != PersonSource.anilistCharacter &&
                    p.subtitle != null &&
                    p.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.subtitle!,
                      style: AppText.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _characterHeader(PersonProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 238,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 166,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (p.photo != null && p.photo!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: p.photo!,
                        fit: BoxFit.cover,
                        memCacheWidth: 900,
                        errorWidget: (_, _, _) =>
                            Container(color: AppColors.surface2),
                      )
                    else
                      Container(color: AppColors.surface2),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.bg.withValues(alpha: 0.48),
                            AppColors.bg.withValues(alpha: 0.88),
                            AppColors.bg,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                top: 20,
                child: SizedBox(
                  width: 126,
                  height: 168,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (p.photo != null && p.photo!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: p.photo!,
                            fit: BoxFit.cover,
                            memCacheWidth: 378,
                            placeholder: (_, _) =>
                                Container(color: AppColors.surface2),
                            errorWidget: (_, _, _) =>
                                const _PortraitFallback(),
                          )
                        : const _PortraitFallback(),
                  ),
                ),
              ),
              Positioned(
                left: 156,
                right: 16,
                top: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName(p.name),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(
                        fontSize: 23,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (p.nativeName != null && p.nativeName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        p.nativeName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: p.alternateNames
                .where((name) => name.trim().isNotEmpty)
                .map(
                  (name) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(name, style: AppText.caption),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  List<(String, String)> _manualCharacterFacts(String description) {
    final pattern = RegExp(r'^\s*__(.+?):__\s*(.+?)\s*$', multiLine: true);
    return pattern
        .allMatches(description)
        .map((match) => (match.group(1)!.trim(), match.group(2)!.trim()))
        .where((fact) => fact.$1.isNotEmpty && fact.$2.isNotEmpty)
        .toList();
  }

  String _bioWithoutManualFacts(String description) {
    final pattern = RegExp(r'^\s*__.+?:__\s*.+?\s*$', multiLine: true);
    return description.replaceAll(pattern, '').trim();
  }

  bool _hasCharacterFacts(PersonProfile p) =>
      p.age != null ||
      p.gender != null ||
      p.birthday != null ||
      p.bloodType != null ||
      p.favourites != null ||
      (p.description != null &&
          _manualCharacterFacts(p.description!).isNotEmpty);

  Widget _characterFacts(PersonProfile p) {
    final facts = <(String, String)>[
      if (p.age != null) ('Usia', p.age!),
      if (p.gender != null) ('Gender', _genderLabel(p.gender!)),
      if (p.birthday != null) ('Ulang tahun', p.birthday!),
      if (p.bloodType != null) ('Golongan darah', p.bloodType!),
      if (p.favourites != null)
        ('Favorit AniList', p.favourites!.toString()),
      if (p.description != null)
        ..._manualCharacterFacts(p.description!),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Info'),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: facts.map((fact) {
                  return Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fact.$1,
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fact.$2,
                          style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _genderLabel(String value) {
    switch (value.toLowerCase()) {
      case 'female':
        return 'Perempuan';
      case 'male':
        return 'Laki-laki';
      case 'non-binary':
        return 'Non-biner';
      default:
        return value;
    }
  }

  Widget _bio(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Divider(color: AppColors.hairline, height: 1),
        ),
        _sectionLabel('Biografi'),
        GestureDetector(
      onTap: () => setState(() => _bioExpanded = !_bioExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _bioExpanded ? double.infinity : 112,
                ),
                child: AutoTranslatedAniListMarkdown(
                  data: text,
                  textStyle: AppText.body,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _bioExpanded ? 'Sembunyikan' : 'Baca selengkapnya',
              style: AppText.caption.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
      ],
    );
  }

  Widget _relatedRow(List<PersonRef> people) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Pengisi suara'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final r = people[i];
              return GestureDetector(
                onTap: () => _openRelated(r),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: (r.photo != null && r.photo!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: r.photo!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      Container(color: AppColors.surface2),
                                  errorWidget: (_, _, _) =>
                                      const _PortraitFallback(),
                                )
                              : const _PortraitFallback(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(text, style: AppText.overline),
  );

  String _translatedRole(String value) {
    return value
        .replaceAll(RegExp(r'\bMain\b', caseSensitive: false), 'Utama')
        .replaceAll(RegExp(r'\bSupporting\b', caseSensitive: false), 'Pendukung');
  }

  Widget _workCard(PersonWork w) {
    return GestureDetector(
      onTap: () => _openWork(w),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: (w.cover != null && w.cover!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: w.cover!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.surface2),
                    )
                  : Container(color: AppColors.surface2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            w.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: AppColors.textPrimary),
          ),
          if (w.subtitle != null && w.subtitle!.isNotEmpty)
            Text(
              _translatedRole(w.subtitle!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface2,
    alignment: Alignment.center,
    child: const Icon(
      Icons.person_rounded,
      color: AppColors.textTertiary,
      size: 34,
    ),
  );
}
, multiLine: true);
    return pattern
        .allMatches(description)
        .map((match) => (match.group(1)!.trim(), match.group(2)!.trim()))
        .where((fact) => fact.$1.isNotEmpty && fact.$2.isNotEmpty)
        .toList();
  }

  String _bioWithoutManualFacts(String description) {
    final pattern = RegExp(r'^\\s*__.+?:__\\s*.+?\\s*
      if (p.age != null) ('Usia', p.age!),
      if (p.gender != null) ('Gender', _genderLabel(p.gender!)),
      if (p.birthday != null) ('Ulang tahun', p.birthday!),
      if (p.bloodType != null) ('Golongan darah', p.bloodType!),
      if (p.favourites != null)
        ('Favorit AniList', p.favourites!.toString()),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Informasi karakter'),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: facts.map((fact) {
                  return Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fact.$1,
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fact.$2,
                          style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _genderLabel(String value) {
    switch (value.toLowerCase()) {
      case 'female':
        return 'Perempuan';
      case 'male':
        return 'Laki-laki';
      case 'non-binary':
        return 'Non-biner';
      default:
        return value;
    }
  }

  Widget _bio(String text) {
    return GestureDetector(
      onTap: () => setState(() => _bioExpanded = !_bioExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _bioExpanded ? double.infinity : 112,
                ),
                child: AutoTranslatedAniListMarkdown(
                  data: text,
                  textStyle: AppText.body,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _bioExpanded ? 'Sembunyikan' : 'Baca selengkapnya',
              style: AppText.caption.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relatedRow(List<PersonRef> people) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Pengisi suara'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final r = people[i];
              return GestureDetector(
                onTap: () => _openRelated(r),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: (r.photo != null && r.photo!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: r.photo!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      Container(color: AppColors.surface2),
                                  errorWidget: (_, _, _) =>
                                      const _PortraitFallback(),
                                )
                              : const _PortraitFallback(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(text, style: AppText.overline),
  );

  String _translatedRole(String value) {
    return value
        .replaceAll(RegExp(r'\bMain\b', caseSensitive: false), 'Utama')
        .replaceAll(RegExp(r'\bSupporting\b', caseSensitive: false), 'Pendukung');
  }

  Widget _workCard(PersonWork w) {
    return GestureDetector(
      onTap: () => _openWork(w),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: (w.cover != null && w.cover!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: w.cover!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.surface2),
                    )
                  : Container(color: AppColors.surface2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            w.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: AppColors.textPrimary),
          ),
          if (w.subtitle != null && w.subtitle!.isNotEmpty)
            Text(
              _translatedRole(w.subtitle!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface2,
    alignment: Alignment.center,
    child: const Icon(
      Icons.person_rounded,
      color: AppColors.textTertiary,
      size: 34,
    ),
  );
}
, multiLine: true);
    return description.replaceAll(pattern, '').trim();
  }

  bool _hasCharacterFacts(PersonProfile p) =>
      p.age != null ||
      p.gender != null ||
      p.birthday != null ||
      p.bloodType != null ||
      p.favourites != null ||
      (p.description != null &&
          _manualCharacterFacts(p.description!).isNotEmpty);

  Widget _characterFacts(PersonProfile p) {
    final facts = <(String, String)>[
      if (p.age != null) ('Usia', p.age!),
      if (p.gender != null) ('Gender', _genderLabel(p.gender!)),
      if (p.birthday != null) ('Ulang tahun', p.birthday!),
      if (p.bloodType != null) ('Golongan darah', p.bloodType!),
      if (p.favourites != null)
        ('Favorit AniList', p.favourites!.toString()),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Informasi karakter'),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: facts.map((fact) {
                  return Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fact.$1,
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fact.$2,
                          style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _genderLabel(String value) {
    switch (value.toLowerCase()) {
      case 'female':
        return 'Perempuan';
      case 'male':
        return 'Laki-laki';
      case 'non-binary':
        return 'Non-biner';
      default:
        return value;
    }
  }

  Widget _bio(String text) {
    return GestureDetector(
      onTap: () => setState(() => _bioExpanded = !_bioExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _bioExpanded ? double.infinity : 112,
                ),
                child: AutoTranslatedAniListMarkdown(
                  data: text,
                  textStyle: AppText.body,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _bioExpanded ? 'Sembunyikan' : 'Baca selengkapnya',
              style: AppText.caption.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relatedRow(List<PersonRef> people) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Pengisi suara'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final r = people[i];
              return GestureDetector(
                onTap: () => _openRelated(r),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: (r.photo != null && r.photo!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: r.photo!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      Container(color: AppColors.surface2),
                                  errorWidget: (_, _, _) =>
                                      const _PortraitFallback(),
                                )
                              : const _PortraitFallback(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(text, style: AppText.overline),
  );

  String _translatedRole(String value) {
    return value
        .replaceAll(RegExp(r'\bMain\b', caseSensitive: false), 'Utama')
        .replaceAll(RegExp(r'\bSupporting\b', caseSensitive: false), 'Pendukung');
  }

  Widget _workCard(PersonWork w) {
    return GestureDetector(
      onTap: () => _openWork(w),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: (w.cover != null && w.cover!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: w.cover!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.surface2),
                    )
                  : Container(color: AppColors.surface2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            w.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: AppColors.textPrimary),
          ),
          if (w.subtitle != null && w.subtitle!.isNotEmpty)
            Text(
              _translatedRole(w.subtitle!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface2,
    alignment: Alignment.center,
    child: const Icon(
      Icons.person_rounded,
      color: AppColors.textTertiary,
      size: 34,
    ),
  );
}
