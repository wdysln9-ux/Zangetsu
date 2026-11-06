import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_app/core/models/media_item.dart';
import 'package:watch_app/core/models/provider_info.dart';
import 'package:watch_app/core/ui/featured_banner_edge.dart';
import 'package:watch_app/core/ui/featured_banner_panels.dart';
import 'package:watch_app/core/ui/featured_hero.dart' show HeroMeta;

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Show $id',
  url: 'https://example.test/$id',
  type: ProviderType.anime,
  sourceId: 'test',
);

void main() {
  testWidgets('edge banner replaces all pages when source results change', (
    tester,
  ) async {
    final requested = <String>[];
    Future<HeroMeta?> meta(MediaItem item) async {
      requested.add(item.id);
      return null;
    }

    Widget build(List<MediaItem> items) => MaterialApp(
      home: Scaffold(
        body: FeaturedBannerEdge(items: items, onInfo: (_) {}, meta: meta),
      ),
    );

    await tester.pumpWidget(
      build([_item('same-first'), _item('old-source-second')]),
    );
    await tester.pump();
    await tester.pumpWidget(
      build([_item('same-first'), _item('new-source-second')]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(requested, contains('new-source-second'));
    expect(requested, isNot(contains('old-source-second')));
  });

  testWidgets('panels banner replaces all pages when source results change', (
    tester,
  ) async {
    final played = <String>[];
    Future<HeroMeta?> meta(MediaItem item) async {
      return null;
    }

    Widget build(List<MediaItem> items) => MaterialApp(
      home: Scaffold(
        body: FeaturedBannerPanels(
          items: items,
          inList: (_) => false,
          onPlay: (item) => played.add(item.id),
          onInfo: (_) {},
          onToggleList: (_) {},
          meta: meta,
        ),
      ),
    );

    await tester.pumpWidget(
      build([_item('same-first'), _item('old-source-second')]),
    );
    await tester.pump();
    await tester.pumpWidget(
      build([_item('same-first'), _item('new-source-second')]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bannerSidePanel1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bannerPanelPlay')));

    expect(played, ['new-source-second']);
  });
}
