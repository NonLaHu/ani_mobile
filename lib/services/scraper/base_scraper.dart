import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Base scraping utility providing standardized Dio HTTP configuration,
/// header injection, error tolerance, regex extraction, and HTML parsing helpers.
abstract class BaseScraper {
  late final Dio dio;

  /// Standard desktop user agent commonly used to bypass basic bot guards
  static const String defaultUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36 ani-mobile/1.0';

  BaseScraper({Dio? customDio}) {
    dio = customDio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 15),
            headers: {
              'User-Agent': defaultUserAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
            },
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

    // Logging interceptor for debugging network calls
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Ensure referer exists if origin is present
          if (options.headers['Referer'] == null && options.headers['Origin'] != null) {
            options.headers['Referer'] = '${options.headers['Origin']}/';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Custom error logging or retry hooks can be plugged in here
          return handler.next(error);
        },
      ),
    );
  }

  /// Builds a standard header map with custom Referer and User-Agent
  Map<String, String> buildHeaders({
    String? referer,
    String? userAgent,
    Map<String, String>? extra,
  }) {
    final map = <String, String>{
      'User-Agent': userAgent ?? defaultUserAgent,
      if (referer != null) 'Referer': referer,
      'Sec-Fetch-Dest': 'video',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'cross-site',
    };
    if (extra != null) {
      map.addAll(extra);
    }
    return map;
  }

  /// Fetches an HTML document from [url] and parses it with package:html
  Future<Document> fetchHtml(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await dio.get<String>(
      url,
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
      ),
    );

    if (response.data == null) {
      throw Exception('Empty response from $url');
    }
    return html_parser.parse(response.data);
  }

  /// Fetches JSON from [url]
  Future<dynamic> fetchJson(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await dio.get<dynamic>(
      url,
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.json,
        headers: headers,
      ),
    );
    return response.data;
  }

  /// Extracts single regex capture group or returns [fallback]
  String extractRegex(
    String input,
    RegExp regex, {
    int group = 1,
    String fallback = '',
  }) {
    final match = regex.firstMatch(input);
    if (match != null && match.groupCount >= group) {
      return match.group(group) ?? fallback;
    }
    return fallback;
  }

  /// Extracts all matching capture groups
  List<String> extractAllRegex(
    String input,
    RegExp regex, {
    int group = 1,
  }) {
    final matches = regex.allMatches(input);
    final results = <String>[];
    for (final m in matches) {
      if (m.groupCount >= group) {
        final val = m.group(group);
        if (val != null) results.add(val);
      }
    }
    return results;
  }

  /// Safely decodes base64 strings with or without padding
  String decodeBase64Safe(String encoded) {
    try {
      var normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      return utf8.decode(base64Decode(normalized));
    } catch (_) {
      return '';
    }
  }

  /// Cleans raw HTML text by removing excessive whitespace and decoding entities
  String cleanHtmlText(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}
