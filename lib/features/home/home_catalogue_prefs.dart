import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Home-only catalogue choice. It does not change the app's active source or
/// the source used for playback and downloads.
class HomeCataloguePrefs {
  HomeCataloguePrefs._();

  static const boxName = 'app_prefs';
  static const _modeKey = 'homeCatalogueMode';
  static const _sourceIdKey = 'homeCatalogueSourceId';
  static ValueNotifier<bool>? _sourceSelection;

  static bool get sourceSelected =>
      Hive.isBoxOpen(boxName) && Hive.box(boxName).get(_modeKey) == 'source';

  static ValueNotifier<bool> get sourceSelection {
    final selected = sourceSelected;
    final notifier = _sourceSelection ??= ValueNotifier(selected);
    if (notifier.value != selected) notifier.value = selected;
    return notifier;
  }

  static String? get sourceId {
    if (!Hive.isBoxOpen(boxName)) return null;
    final id = Hive.box(boxName).get(_sourceIdKey);
    return id is String && id.isNotEmpty ? id : null;
  }

  static Future<void> setSourceSelected(bool selected) async {
    if (!Hive.isBoxOpen(boxName)) return;
    await Hive.box(boxName).put(_modeKey, selected ? 'source' : 'metadata');
    _sourceSelection?.value = selected;
  }

  static Future<void> setSourceId(String id) async {
    if (!Hive.isBoxOpen(boxName) || id.isEmpty) return;
    await Hive.box(boxName).put(_sourceIdKey, id);
  }
}
