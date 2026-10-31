import 'package:dio/dio.dart';

/// Best-effort lookup of the exact size advertised by a remote file host.
class RemoteFileSize {
  RemoteFileSize._();
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
    followRedirects: true,
  ));

  static Future<int?> lookup(String url, {Map<String, String>? headers}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    try {
      final response = await _dio.head(url, options: Options(headers: headers));
      final length = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '');
      if (length != null && length > 0) return length;
      final range = RegExp(r'/([0-9]+)$').firstMatch(response.headers.value('content-range') ?? '');
      final total = int.tryParse(range?.group(1) ?? '');
      return total != null && total > 0 ? total : null;
    } catch (_) { return null; }
  }

  static String format(int bytes) {
    const mb = 1024 * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}