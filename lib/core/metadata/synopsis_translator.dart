import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Translates catalogue synopses into Indonesian without changing source data.
/// Successful translations are persisted so a synopsis is translated only once.
class SynopsisTranslator {
  SynopsisTranslator._();

  static final SynopsisTranslator instance = SynopsisTranslator._();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 8),
      headers: const {'User-Agent': 'Zangetsu/1.0'},
    ),
  );

  // Titles and episode headings must resolve to one identical Indonesian
  // result wherever they appear (anime detail, episode detail, player and
  // playlist). A shared cache key prevents separate translation paths from
  // storing different wording for the same source text.
  static const _indonesianTextCachePrefix = 'indonesian_text_v2_';

  Future<String?> translateToIndonesian(String raw) =>
      _translate(raw, cachePrefix: _indonesianTextCachePrefix);

  Future<String?> translateTextToIndonesian(String raw) =>
      _translate(raw, cachePrefix: _indonesianTextCachePrefix);

  Future<String?> _translate(
    String raw, {
    required String cachePrefix,
  }) async {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final key = '$cachePrefix${sha256.convert(utf8.encode(text))}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      if (saved != null && saved.isNotEmpty) return saved;

      final response = await _dio.get<dynamic>(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': 'id',
          'dt': 't',
          'q': text,
        },
      );

      final data = response.data;
      if (data is! List || data.isEmpty || data[0] is! List) return null;
      final translated = StringBuffer();
      for (final part in data[0] as List) {
        if (part is List && part.isNotEmpty && part[0] is String) {
          translated.write(part[0] as String);
        }
      }
      final result = translated.toString().trim();
      if (result.isEmpty) return null;
      await prefs.setString(key, result);
      return result;
    } on DioException {
      return null;
    } catch (_) {
      // Translation is optional: never let a translation/cache failure break
      // opening a page.
      return null;
    }
  }
}
