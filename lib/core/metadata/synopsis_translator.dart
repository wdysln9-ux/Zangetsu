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

  Future<String?> translateToIndonesian(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final key = 'synopsis_id_${sha256.convert(utf8.encode(text))}';
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
      // opening the anime detail page.
      return null;
    }
  }
}
