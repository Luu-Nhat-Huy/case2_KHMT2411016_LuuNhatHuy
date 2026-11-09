import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  // Android Emulator truy cập máy tính qua 10.0.2.2.
  // Nếu chạy trên điện thoại thật, đổi thành IP LAN của máy tính.
  static const String baseUrl = 'http://10.0.2.2:3000';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveSession(String token, Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    if (user != null) {
      await prefs.setString('user', jsonEncode(user));
    }
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) { return null; }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _decode(http.Response response) {
    dynamic body;
    try { body = response.body.isEmpty ? {} : jsonDecode(response.body); }
    catch (_) { body = {'message': response.body}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map
          ? (body['message'] ?? body['error'] ?? body['msg'] ?? 'Yêu cầu thất bại (${response.statusCode})').toString()
          : 'Yêu cầu thất bại (${response.statusCode})';
      throw ApiException(message);
    }
    return body;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (data is! Map) throw ApiException('Dữ liệu đăng nhập không hợp lệ');
    final map = Map<String, dynamic>.from(data);
    final token = map['token']?.toString();
    if (token == null || token.isEmpty) throw ApiException('Backend không trả về token');
    await saveSession(token, map['user'] is Map ? Map<String, dynamic>.from(map['user']) : null);
    return map;
  }

  static Future<Map<String, dynamic>> register(String fullName, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: await _headers(),
      body: jsonEncode({'fullName': fullName, 'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (data is! Map) throw ApiException('Dữ liệu đăng ký không hợp lệ');
    final map = Map<String, dynamic>.from(data);
    final token = map['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await saveSession(token, map['user'] is Map ? Map<String, dynamic>.from(map['user']) : null);
    }
    return map;
  }


  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/profile'),
      headers: await _headers(auth: true),
    ).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    final user = data is Map ? (data['user'] ?? data['data'] ?? data) : null;
    if (user is! Map) throw ApiException('Dữ liệu hồ sơ không hợp lệ');
    final result = Map<String, dynamic>.from(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(result));
    return result;
  }

  static Future<Map<String, dynamic>> updateProfile(String fullName, String email) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/auth/profile'),
      headers: await _headers(auth: true),
      body: jsonEncode({'fullName': fullName, 'email': email}),
    ).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    final user = data is Map ? (data['user'] ?? data['data'] ?? data) : null;
    if (user is! Map) throw ApiException('Dữ liệu hồ sơ không hợp lệ');
    final result = Map<String, dynamic>.from(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(result));
    return result;
  }

  static Future<void> changePassword(String currentPassword, String newPassword, String confirmPassword) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/auth/change-password'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    ).timeout(const Duration(seconds: 20));
    _decode(response);
  }

  static Future<List<Map<String, dynamic>>> getTasks({
    String search = '',
    String status = 'all',
    String priority = 'all',
    String sortBy = 'createdAt',
    String order = 'desc',
    String view = 'all',
    String assignee = 'all',
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks').replace(queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (status != 'all') 'status': status,
      if (priority != 'all') 'priority': priority,
      if (assignee != 'all') 'assignee': assignee,
      'sortBy': sortBy,
      'order': order,
      'view': view,
    });
    final response = await http.get(uri, headers: await _headers(auth: true))
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    dynamic list = data;
    if (data is Map) list = data['tasks'] ?? data['data'] ?? data['results'] ?? [];
    if (list is! List) throw ApiException('Backend trả về danh sách công việc không hợp lệ');
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getTaskUsers({String search = ''}) async {
    final uri = Uri.parse('$baseUrl/api/tasks/users').replace(
      queryParameters: search.trim().isEmpty ? null : {'search': search.trim()},
    );
    final response = await http.get(uri, headers: await _headers(auth: true))
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    final users = data is Map ? data['users'] : null;
    if (users is! List) throw ApiException('Backend trả về danh sách người dùng không hợp lệ');
    return users.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> getTaskById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tasks/$id'),
      headers: await _headers(auth: true),
    ).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (data is! Map) throw ApiException('Dữ liệu chi tiết công việc không hợp lệ');
    final task = data['task'] ?? data['data'] ?? data;
    if (task is! Map) throw ApiException('Không tìm thấy dữ liệu công việc');
    return Map<String, dynamic>.from(task);
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> task) async {
    final response = await http.post(Uri.parse('$baseUrl/api/tasks'),
      headers: await _headers(auth: true), body: jsonEncode(task)).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> task) async {
    final response = await http.put(Uri.parse('$baseUrl/api/tasks/$id'),
      headers: await _headers(auth: true), body: jsonEncode(task)).timeout(const Duration(seconds: 20));
    final data = _decode(response);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<void> deleteTask(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/tasks/$id'), headers: await _headers(auth: true))
        .timeout(const Duration(seconds: 20));
    _decode(response);
  }
}
