import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  // Đổi IP này thành IP VPS của bạn (hoặc domain)
  static const base = 'http://YOUR_VPS_IP:3000';
  static String? _token;
  static String? _refresh;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('access');
    _refresh = p.getString('refresh');
  }

  static Future<void> saveTokens(String access, String refresh) async {
    _token = access;
    _refresh = refresh;
    final p = await SharedPreferences.getInstance();
    await p.setString('access', access);
    await p.setString('refresh', refresh);
  }

  static Future<void> logout() async {
    _token = null;
    _refresh = null;
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }

  static bool get isLoggedIn => _token != null;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> _req(
    String method, String path, [Map<String, dynamic>? body]
  ) async {
    final uri = Uri.parse('$base$path');
    late http.Response r;
    if (method == 'GET') {
      r = await http.get(uri, headers: _headers);
    } else {
      r = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
    }
    if (r.statusCode >= 400) {
      throw Exception('API ${r.statusCode}: ${r.body}');
    }
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> requestOtp(String phone) =>
    _req('POST', '/auth/request-otp', {'phone': phone});

  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _req('POST', '/auth/verify-otp', {
      'phone': phone, 'otp': otp,
    });
    await saveTokens(res['access'], res['refresh']);
    return res;
  }

  static Future<Map<String, dynamic>> createInvite() =>
    _req('POST', '/couples/invite');

  static Future<Map<String, dynamic>> joinCouple(String code) =>
    _req('POST', '/couples/join', {'code': code});

  static Future<Map<String, dynamic>> myCouple() =>
    _req('GET', '/couples/me');

  static Future<Map<String, dynamic>> myPet() => _req('GET', '/pets/me');

  static Future<Map<String, dynamic>> interact(String action) =>
    _req('POST', '/pets/interact', {'action': action});

  static Future<List<dynamic>> messages() async {
    final uri = Uri.parse('$base/messages?limit=50');
    final r = await http.get(uri, headers: _headers);
    return jsonDecode(r.body) as List<dynamic>;
  }
}
