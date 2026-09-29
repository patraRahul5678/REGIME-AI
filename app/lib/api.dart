import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  // Web/Chrome -> localhost ; Android emulator -> 10.0.2.2 ; real device -> your PC's LAN IP
  static const base = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:4000/api');
  static String? token;
  static Map<String, dynamic>? user;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
  }

  static Future<void> _save(Map d) async {
    token = d['token'];
    user = Map<String, dynamic>.from(d['user']);
    (await SharedPreferences.getInstance()).setString('token', token!);
  }

  static Future<Map<String, dynamic>> _req(String m, String path, [Map? body]) async {
    final h = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
    final u = Uri.parse('$base$path');
    try {
      final r = m == 'GET' ? await http.get(u, headers: h).timeout(const Duration(seconds: 90))
          : m == 'PUT' ? await http.put(u, headers: h, body: jsonEncode(body))
          : await http.post(u, headers: h, body: jsonEncode(body ?? {}));
      final d = jsonDecode(r.body);
      if (r.statusCode >= 400) throw (d['error'] ?? 'Request failed');
      return d;
    } on String { rethrow; } catch (_) { throw 'Cannot reach server. Is the backend running?'; }
  }

  static Future<void> login(String e, String p) async => _save(await _req('POST', '/auth/login', {'email': e, 'password': p}));
  static Future<void> register(Map b) async => _save(await _req('POST', '/auth/register', b));
  static Future<bool> restore() async {
    if (token == null) return false;
    try { user = Map<String, dynamic>.from((await _req('GET', '/auth/me'))['user']); return true; } catch (_) { return false; }
  }
  static Future<void> updateProfile(Map b) async => user = Map<String, dynamic>.from((await _req('PUT', '/auth/me', b))['user']);
  static Future<void> logout() async {
    try { await _req('POST', '/auth/logout'); } catch (_) {}
    token = null; user = null;
    (await SharedPreferences.getInstance()).remove('token');
  }
  static Future<Map<String, dynamic>> get(String path) => _req('GET', path);
}
