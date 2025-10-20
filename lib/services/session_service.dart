import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _key = 'session';

  static Future<void> saveSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session));
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return null;

    try {
      final Map<String, dynamic> decoded = jsonDecode(data);

      if (decoded['orgs'] is String) {
        decoded['orgs'] = jsonDecode(decoded['orgs']);
      }
      if (decoded['roles'] is String) {
        decoded['roles'] = jsonDecode(decoded['roles']);
      }

      return decoded;
    } catch (e) {
      print('Error loading session: $e');
      await prefs.remove(_key);
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<String?> getUserId() async {
    final session = await loadSession();
    return session?['user_id'];
  }

  static Future<String?> getOrgId() async {
    final session = await loadSession();
    final orgs = session?['orgs'];
    if (orgs is List && orgs.isNotEmpty) {
      return orgs[0]['org_id'];
    }
    return null;
  }
}