import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class Api {
  static const base = 'http://123.30.139.107:3000';
  static String? _token;
  static String? _refresh;

  static File _getStorageFile() {
    final dir = Directory.systemTemp;
    return File('${dir.path}/dynlove_session.json');
  }

  static Future<void> load() async {
    try {
      final file = _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _token = data['access'];
        _refresh = data['refresh'];
      }
    } catch (_) {}
  }

  static Future<void> saveTokens(String access, String refresh) async {
    _token = access;
    _refresh = refresh;
    try {
      final file = _getStorageFile();
      await file.writeAsString(jsonEncode({'access': access, 'refresh': refresh}));
    } catch (_) {}
  }

  static Future<void> logout() async {
    _token = null;
    _refresh = null;
    try {
      final file = _getStorageFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
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
      r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    } else {
      r = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10));
    }
    if (r.statusCode >= 400) {
      String msg = r.body;
      try {
        final decoded = jsonDecode(r.body);
        msg = decoded['message'] ?? decoded['error'] ?? r.body;
      } catch (_) {}
      throw Exception(msg);
    }
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ── Auth ──
  static Future<Map<String, dynamic>> requestOtp(String phone) =>
    _req('POST', '/auth/request-otp', {'phone': phone});

  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _req('POST', '/auth/verify-otp', {'phone': phone, 'otp': otp});
    await saveTokens(res['access'], res['refresh']);
    return res;
  }

  // ── Couples ──
  static Future<Map<String, dynamic>> createInvite() =>
    _req('POST', '/couples/invite');

  static Future<Map<String, dynamic>> joinCouple(String code, {String? startLoveDate}) =>
    _req('POST', '/couples/join', {
      'code': code,
      if (startLoveDate != null) 'startLoveDate': startLoveDate,
    });

  static Future<Map<String, dynamic>> myCouple() => _req('GET', '/couples/me');

  // ── Pet ──
  static Future<Map<String, dynamic>> myPet() => _req('GET', '/pets/me');

  static Future<Map<String, dynamic>> interact(String action) =>
    _req('POST', '/pets/interact', {'action': action});

  // ── Check-in ──
  static Future<Map<String, dynamic>> checkin() => _req('POST', '/checkin');

  // ── Missions ──
  static Future<Map<String, dynamic>> missions() => _req('GET', '/missions');

  // ── Messages ──
  static Future<List<dynamic>> messages() async {
    final uri = Uri.parse('$base/messages?limit=50');
    final r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body) as List<dynamic>;
  }
}
