import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watch_app/features/home/home_catalogue_prefs.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('home_catalogue_prefs');
    Hive.init(tempDir.path);
    await Hive.openBox(HomeCataloguePrefs.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('new installs keep the existing metadata Home', () {
    expect(HomeCataloguePrefs.sourceSelected, isFalse);
    expect(HomeCataloguePrefs.sourceId, isNull);
  });

  test(
    'source catalogue and chosen source survive reopening the box',
    () async {
      await HomeCataloguePrefs.setSourceSelected(true);
      await HomeCataloguePrefs.setSourceId('mihon:reader');
      await Hive.box(HomeCataloguePrefs.boxName).close();
      await Hive.openBox(HomeCataloguePrefs.boxName);

      expect(HomeCataloguePrefs.sourceSelected, isTrue);
      expect(HomeCataloguePrefs.sourceId, 'mihon:reader');

      await HomeCataloguePrefs.setSourceSelected(false);
      expect(HomeCataloguePrefs.sourceSelected, isFalse);
      expect(HomeCataloguePrefs.sourceId, 'mihon:reader');
    },
  );

  test('changing the catalogue selection notifies the mounted Home', () async {
    final changes = <bool>[];
    final selection = HomeCataloguePrefs.sourceSelection;
    void onChanged() => changes.add(selection.value);
    selection.addListener(onChanged);
    addTearDown(() => selection.removeListener(onChanged));

    await HomeCataloguePrefs.setSourceSelected(true);

    expect(changes, [true]);
    expect(selection.value, isTrue);
  });

  test('a closed box falls back without changing Home', () async {
    await Hive.box(HomeCataloguePrefs.boxName).close();
    expect(HomeCataloguePrefs.sourceSelected, isFalse);
    expect(HomeCataloguePrefs.sourceId, isNull);
  });
}
