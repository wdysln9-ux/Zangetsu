// Credits line, description block, icon actions and the tab-bar header.
part of 'detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Muted credit line: "Starring: a, b, c… more" / "Creators: …" / "Genres: …".
// The label is slightly dimmer than the value, matching Netflix's hierarchy.
// ─────────────────────────────────────────────────────────────────────────────

class _CreditLine extends StatelessWidget {
  const _CreditLine({
    required this.label,
    required this.value,
    this.more = false,
    this.onMore,
  });

  final String label;
  final String value;

  /// When true, append a "… more" affordance. When [onMore] is also set, the
  /// whole line is tappable and jumps to the relevant tab (Cast).
  final bool more;

  /// Tapping the line (or its "… more") jumps to the related tab. Null = inert.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final base = AppText.caption.copyWith(color: AppColors.textSecondary);
    final line = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: base.copyWith(color: AppColors.textTertiary),
            ),
            TextSpan(text: value, style: base),
            if (more)
              TextSpan(
                text: '… more',
                style: base.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (onMore == null) return line;
    return GestureDetector(
      onTap: onMore,
      behavior: HitTestBehavior.opaque,
      child: line,
    );
  }
}

// Compact credit line with individually tappable values.
class _InteractiveCreditLine extends StatelessWidget {
  const _InteractiveCreditLine({
    required this.label,
    required this.values,
    required this.onTap,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Text('$label:', style: style.copyWith(color: AppColors.textTertiary)),
          for (var i = 0; i < values.length; i++)
            GestureDetector(
              onTap: () => onTap(values[i]),
              child: Text(
                '${values[i]}${i < values.length - 1 ? ',' : ''}',
                style: style.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Description: synopsis preview with an inline expand/collapse affordance.
// ─────────────────────────────────────────────────────────────────────────────

class _Description extends StatefulWidget {
  const _Description({required this.text});
  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: _SynopsisTranslation(text: widget.text, expanded: _expanded),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Text(
            _expanded ? 'Lebih sedikit' : context.l10n.readMore,
            style: AppText.caption.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Automatically translates the synopsis while keeping the source text intact.
class _SynopsisTranslation extends StatefulWidget {
  const _SynopsisTranslation({required this.text, required this.expanded});
  final String text;
  final bool expanded;

  @override
  State<_SynopsisTranslation> createState() => _SynopsisTranslationState();
}

class _SynopsisTranslationState extends State<_SynopsisTranslation> {
  String? _translated;

  @override
  void initState() {
    super.initState();
    _loadTranslation();
  }

  @override
  void didUpdateWidget(covariant _SynopsisTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translated = null;
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    final result = await SynopsisTranslator.instance.translateToIndonesian(widget.text);
    if (!mounted) return;
    setState(() {
      _translated = result != widget.text ? result : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final markdown = AniListMarkdown(
      data: _translated ?? widget.text,
      textStyle: AppText.body,
    );
    if (widget.expanded) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: markdown,
      );
    }
    final lineHeight = (AppText.body.fontSize ?? 14) *
        (AppText.body.height ?? 1.45);
    return ClipRect(
      child: SizedBox(
        height: lineHeight * 3,
        child: markdown,
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// One of the 5 outlined icon actions.
// ─────────────────────────────────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;

  /// Small caption shown under the icon (Netflix-style icon-over-label).
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textPrimary;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppText.caption.copyWith(
                  color: active ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned tab-bar delegate.
// ─────────────────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, {this.tint});
  final TabBar tabBar;
  final ValueListenable<Color?>? tint;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // No divider line under the bar — just the left-aligned tabs (Sozo Read).
    final t = tint;
    if (t == null) {
      return Material(color: AppColors.bg, elevation: 0, child: tabBar);
    }
    return ValueListenableBuilder<Color?>(
      valueListenable: t,
      builder: (context, c, _) =>
          Material(color: c ?? AppColors.bg, elevation: 0, child: tabBar),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || tint != oldDelegate.tint;
}
