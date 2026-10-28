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

// ─────────────────────────────────────────────────────────────────────────────
// Description: synopsis clamped to 3 lines + a red "Read more" that opens the
// Details tab (which shows the full synopsis). No inline expand.
// ─────────────────────────────────────────────────────────────────────────────

class _Description extends StatefulWidget {
  const _Description({required this.text, required this.onReadMore});
  final String text;
  final VoidCallback onReadMore;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  String? _translated;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _loadTranslation();
  }

  @override
  void didUpdateWidget(covariant _Description oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translated = null;
      _showOriginal = false;
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    final result = await SynopsisTranslator.instance.translateToIndonesian(widget.text);
    if (mounted && result != null && result != widget.text) {
      setState(() => _translated = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shownText = !_showOriginal && _translated != null ? _translated! : widget.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onReadMore,
          behavior: HitTestBehavior.opaque,
          child: Text(shownText, style: AppText.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: widget.onReadMore,
              child: Text(context.l10n.readMore, style: AppText.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
            if (_translated != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _showOriginal = !_showOriginal),
                child: Text(_showOriginal ? 'Terjemahan' : 'Asli', style: AppText.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ] else ...[
              const SizedBox(width: 8),
              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
            ],
          ],
        ),
      ],
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
