import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  static const _base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://medroster-backend.vercel.app',
  );

  Map<String, dynamic>? profile;

  bool get canWrite => profile != null && profile!['role'] != 'staff';

  bool get isAdmin => profile != null && profile!['role'] == 'admin';

  bool get hasHospital {
    final id = profile?['hospitalId'];
    return id is String && id.isNotEmpty;
  }

  String? get hospitalId {
    final id = profile?['hospitalId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  String get accountType {
    final t = profile?['accountType']?.toString();
    if (t == 'individual' || t == 'enterprise') return t!;
    return hasHospital ? 'enterprise' : 'individual';
  }

  bool get isIndividualAccount => accountType == 'individual' || !hasHospital;

  void clearProfile() {
    profile = null;
  }

  Future<Map<String, dynamic>> loadProfile() async {
    final me = await get('/api/auth/me');
    profile = Map<String, dynamic>.from(me as Map);
    return profile!;
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getIdToken();
    if (token == null) clearProfile();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base$path'), headers: await _headers())
          .timeout(timeout);
      return _parse(res);
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection and try again.', 408);
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parse(res);
    } on TimeoutException {
      throw ApiException('Request timed out. Large files can take a minute — try again on a stable network.', 408);
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parse(res);
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection and try again.', 408);
    }
  }

  Future<dynamic> delete(String path, {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base$path'), headers: await _headers())
          .timeout(timeout);
      return _parse(res);
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection and try again.', 408);
    }
  }

  /// Authenticated binary download (e.g. CSV template).
  Future<List<int>> getBytes(String path, {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final headers = await _headers();
      headers.remove('Content-Type');
      final res = await http.get(Uri.parse('$_base$path'), headers: headers).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
      dynamic body;
      try {
        body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      } catch (_) {}
      final map = body is Map ? Map<String, dynamic>.from(body) : null;
      throw ApiException(map?['error']?.toString() ?? res.reasonPhrase ?? 'Download failed', res.statusCode, map);
    } on TimeoutException {
      throw ApiException('Download timed out. Check your connection and try again.', 408);
    }
  }

  List<Map<String, dynamic>> asMaps(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  dynamic _parse(http.Response res) {
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final map = body is Map ? Map<String, dynamic>.from(body) : null;
    final message = map?['error']?.toString() ?? res.reasonPhrase ?? 'Unknown error';
    throw ApiException(message, res.statusCode, map);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? data;
  ApiException(this.message, this.statusCode, [this.data]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
