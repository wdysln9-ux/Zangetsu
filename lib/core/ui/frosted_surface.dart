import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Apple-style vibrancy. [blur] true → real BackdropFilter (use ONLY on static
/// overlays: sheets, controls, nav — never inside scrolling content). [blur]
/// false → a translucent fill only (cheap; for scroll contexts). Always
/// RepaintBoundary-wrapped so it never repaints its neighbors.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.blur = true,
    this.opacity = 0.6,
    this.borderRadius,
  });
  final Widget child;
  final bool blur;
  final double opacity;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.zero;
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: opacity),
        borderRadius: r,
      ),
      child: child,
    );
    if (!blur) {
      return RepaintBoundary(
        child: ClipRRect(borderRadius: r, child: fill),
      );
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: fill,
        ),
      ),
    );
  }
}

/// Frosted-glass look from a static sheen. By default it does not sample the
/// pixels behind it; [blur] opts into one clipped live blur for fixed chrome.
class FakeFrost extends StatelessWidget {
  const FakeFrost({
    super.key,
    required this.child,
    this.borderRadius,
    this.opacity = 0.85,
    this.padding,
    this.blur = false,
    this.blurSigma = 18,
  });
  final Widget child;
  final BorderRadius? borderRadius;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final bool blur;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.zero;
    final base = AppColors.surface.withValues(alpha: opacity);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.07), base),
            base,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    return RepaintBoundary(
      // Shadow lives OUTSIDE the clip: inside, the rounded cut would eat it.
      // It paints once with the bar (never samples scrolling content).
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: blur
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: surface,
                )
              : surface,
        ),
      ),
    );
  }
}
