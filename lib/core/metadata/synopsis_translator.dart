import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Gently adapts machine-translated Indonesian to the app's conversational
/// tone. These are phrase-level changes, not broad word substitutions, so
/// they avoid changing the meaning of ordinary sentences.
String _naturalizeIndonesian(String value) {
  var text = value;
  const replacements = <String, String>{
    r'\bsangat\s+(?:saya|aku)\s+(?:nantikan|tunggu)\b': 'aku tunggu banget',
    r'\bsangat\s+kutunggu\b': 'aku tunggu banget',
    r'\bsangat\s+dinantikan\b': 'paling ditunggu',
    r'\bsaya\b': 'aku',
    r'\bAnda\b': 'kamu',
    r'\bapakah\b': 'apa',
    r'\bakan tetapi\b': 'tapi',
    r'\bnamun\b': 'tapi',
    r'\boleh karena itu\b': 'jadi',
    r'\bdapat\b': 'bisa',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAllMapped(
      RegExp(entry.key, caseSensitive: false),
      (match) {
        final replacement = entry.value;
        if (match[0]!.isNotEmpty && match[0]![0].toUpperCase() == match[0]![0]) {
          return replacement[0].toUpperCase() + replacement.substring(1);
        }
        return replacement;
      },
    );
  }
  return text;
}

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
  static const _indonesianTextCachePrefix = 'indonesian_text_v3_';

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
      final result = _naturalizeIndonesian(translated.toString().trim());
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
