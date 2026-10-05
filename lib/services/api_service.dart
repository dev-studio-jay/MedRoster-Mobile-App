import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  static const individualAppMessage =
      'This app is for hospital accounts. Use the MedRoster web app for individual schedules.';

  // Replace with your deployed backend URL in production
  static const _base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://medroster-backend.vercel.app',
  );

  Map<String, dynamic>? profile;

  bool get canWrite => profile != null && profile!['role'] != 'staff';

  bool get hasHospital {
    final id = profile?['hospitalId'];
    return id is String && id.isNotEmpty;
  }

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

  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: await _headers());
    return _parse(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$_base$path'), headers: await _headers());
    return _parse(res);
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
    final message = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : (res.reasonPhrase ?? 'Unknown error');
    throw ApiException(message, res.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
