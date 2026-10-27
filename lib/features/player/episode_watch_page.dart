import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/episode.dart';
import '../../core/theme/app_text.dart';

/// Streaming-style episode page with a video header, show actions and episode rail.
class EpisodeWatchPage extends StatefulWidget {
  const EpisodeWatchPage({
    super.key,
    required this.showTitle,
    required this.episodes,
    required this.startIndex,
    required this.onPlay,
    required this.onSave,
    required this.onDownload,
    this.cover,
  });

  final String showTitle;
  final List<Episode> episodes;
  final int startIndex;
  final String? cover;
  final ValueChanged<int> onPlay;
  final VoidCallback onSave;
  final ValueChanged<Episode> onDownload;

  @override
  State<EpisodeWatchPage> createState() => _EpisodeWatchPageState();
}

class _EpisodeWatchPageState extends State<EpisodeWatchPage> {
  late int _selected = widget.startIndex.clamp(
    0,
    widget.episodes.isEmpty ? 0 : widget.episodes.length - 1,
  ).toInt();

  Episode? get _episode =>
      widget.episodes.isEmpty ? null : widget.episodes[_selected];

  String _label(Episode ep, int index) {
    final n = ep.number;
    final number = n == null
        ? 'Episode ${index + 1}'
        : 'Episode ${n == n.roundToDouble() ? n.toInt() : n}';
    final title = ep.metaTitle?.trim().isNotEmpty == true
        ? ep.metaTitle!.trim()
        : ep.title.trim();
    if (title.isEmpty || title.toLowerCase() == number.toLowerCase()) {
      return number;
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ep = _episode;
    final image = ep?.thumbnail?.trim().isNotEmpty == true
        ? ep!.thumbnail!.trim()
        : (widget.cover ?? '');
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: image.isEmpty
                        ? ColoredBox(color: colors.surfaceContainerHighest)
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: Color(0xFF171717)),
                          ),
                  ),
                  Container(
                    height: 52,
                    width: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xDDF47521),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Putar episode',
                      onPressed: ep == null ? null : () => widget.onPlay(_selected),
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: colors.onPrimary, size: 34),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: colors.onSurface),
                    ),
                  ),

                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(widget.showTitle,
                      style: AppText.title.copyWith(
                        color: colors.onSurface,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 5),
                  Text(ep == null ? '' : _label(ep, _selected),
                      style: AppText.body.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 16,
                      )),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onSave,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Simpan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: ep == null ? null : () => widget.onDownload(ep),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Unduh'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: colors.outline),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(Icons.play_circle_outline,
                          color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Episode',
                          style: AppText.title.copyWith(
                              color: colors.onSurface, fontSize: 19)),
                      const SizedBox(width: 8),
                      Text('${widget.episodes.length} eps',
                          style: AppText.body.copyWith(
                              color: colors.onSurfaceVariant, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 142,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.episodes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = widget.episodes[index];
                        final thumb = item.thumbnail?.trim().isNotEmpty == true
                            ? item.thumbnail!.trim()
                            : (widget.cover ?? '');
                        final selected = index == _selected;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = index),
                          onDoubleTap: () => widget.onPlay(index),
                          child: SizedBox(
                            width: 190,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.accent
                                      : colors.outlineVariant,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (thumb.isNotEmpty)
                                      CachedNetworkImage(
                                        imageUrl: thumb,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const ColoredBox(
                                                color: Color(0xFF171717)),
                                      )
                                    else
                                      const ColoredBox(
                                          color: Color(0xFF171717)),
                                    const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Color(0xDD000000)
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 10,
                                      right: 8,
                                      bottom: 9,
                                      child: Text(
                                        _label(item, index),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.body.copyWith(
                                            color: colors.onSurface,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (selected)
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Icon(Icons.play_circle_fill,
                                            color: colors.primary, size: 22),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ep?.description?.trim().isNotEmpty == true
                                ? ep!.description!.trim()
                                : 'Pilih episode yang ingin ditonton, lalu tekan tombol putar.',
                            style: AppText.body.copyWith(
                                color: colors.onSurfaceVariant, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          ep == null ? null : () => widget.onPlay(_selected),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Putar episode'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
