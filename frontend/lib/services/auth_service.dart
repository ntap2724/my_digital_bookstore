import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/config.dart';
import 'package:my_flutter_app/services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginResult {
  final bool success;
  final String? accessToken;
  final String? message;
  LoginResult({required this.success, this.accessToken, this.message});
}

class AccountInfo {
  final String id; // use email as id for simplicity
  final String email;
  final String? name;
  final String token;

  AccountInfo({
    required this.id,
    required this.email,
    required this.token,
    this.name,
  });

  AccountInfo copyWith({String? email, String? name, String? token}) =>
      AccountInfo(
        id: id,
        email: email ?? this.email,
        name: name ?? this.name,
        token: token ?? this.token,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'token': token,
  };

  static AccountInfo fromJson(Map<String, dynamic> j) => AccountInfo(
    id: (j['id'] ?? j['email']).toString(),
    email: j['email']?.toString() ?? '',
    name: j['name']?.toString(),
    token: j['token']?.toString() ?? '',
  );
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();
  String? _sessionToken; // in-memory token when not persisted
  String? _sessionOwnerId; // lowercase email/id owning the session token

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<bool> emailExists(String email) async {
    final uri = _uri(
      '${AppConfig.emailExistsEndpoint}?email=${Uri.encodeComponent(email)}',
    );
    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _decodeJson(resp.body);
        final ex = data['exists'];
        if (ex is bool) return ex;
        if (ex is String) return ex.toLowerCase() == 'true' || ex == '1';
        if (ex is num) return ex != 0;
      }
    } catch (_) {}
    return false;
  }

  Map<String, dynamic> _decodeJson(String body) {
    var s = body.trimLeft();
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
      s = s.substring(1);
    }
    final firstBrace = s.indexOf('{');
    if (firstBrace > 0) {
      s = s.substring(firstBrace);
    }
    final decoded = jsonDecode(s);
    return decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
  }

  String _toEnglishGender(String value) {
    final s = value.trim().toLowerCase();
    if (s.isEmpty) return 'other';
    if (s == 'male' || s == 'm' || s.startsWith('nam')) return 'male';
    if (s == 'female' || s == 'f' || s == 'nu' || s == 'nữ' || s == 'nữ') {
      return 'female';
    }
    if (s == 'other' || s.startsWith('khac') || s.startsWith('khác')) return 'other';
    return 'other';
  }

  Future<LoginResult> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    if (AppConfig.usePassportPasswordGrant) {
      return _loginWithPassport(
        email: email,
        password: password,
        remember: remember,
      );
    } else {
      return _loginWithSimpleEndpoint(
        email: email,
        password: password,
        remember: remember,
      );
    }
  }

  // Registers a new user via backend and returns an access token on success
  Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required DateTime dob,
    required String gender,
    required bool acceptedTerms,
  }) async {
    final uri = _uri(AppConfig.simpleRegisterEndpoint);
    // Normalize gender to server-expected values if client passes internal keys
    final serverGender = () {
      switch (gender) {
        case 'male':
          return 'Nam';
        case 'female':
          return 'Nữ';
        case 'other':
          return 'Khác';
        default:
          return gender;
      }
    }();
    final serverGenderEn = _toEnglishGender(serverGender);

    final body = {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'phone': phone.replaceAll(RegExp(r'\s+'), '').trim(),
      'dob': _isoDate(dob),
      'gender': serverGenderEn,
      'accepted_terms': acceptedTerms,
    };

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',

              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      return LoginResult(success: false, message: _friendlyNetworkError(e));
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _decodeJson(resp.body);
      final token = (data['access_token'] ?? data['token'])?.toString();
      if (token == null || token.isEmpty) {
        return LoginResult(
          success: false,
          message: 'Thiếu token trong phản hồi',
        );
      }
      // Persist a local account entry (no token) so login badge shows the proper name
      try {
        await _persistLoginAccount(email: email, token: '');
        await _updateAccountName(id: email, name: name);
      } catch (_) {}
      // Navigate to login form after successful registration
      try {
        NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (r) => false,
          arguments: {'email': email},
        );
      } catch (_) {}
      return LoginResult(success: true, accessToken: token);
    }

    try {
      final data = _decodeJson(resp.body);
      final message = data['message']?.toString();
      return LoginResult(
        success: false,
        message: message ?? 'Đăng ký thất bại (${resp.statusCode})',
      );
    } catch (_) {
      return LoginResult(
        success: false,
        message: 'Đăng ký thất bại (${resp.statusCode})',
      );
    }
  }

  Future<LoginResult> _loginWithPassport({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final uri = _uri(AppConfig.passportTokenEndpoint);
    final body = <String, String>{
      'grant_type': 'password',
      'client_id': AppConfig.passportClientId,
      'client_secret': AppConfig.passportClientSecret,
      'username': email,
      'password': password,
      'scope': '*',
    };

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      return LoginResult(success: false, message: _friendlyNetworkError(e));
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _decodeJson(resp.body);
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        return LoginResult(
          success: false,
          message: 'Thiếu access_token trong phản hồi',
        );
      }
      if (remember) {
        await _persistLoginAccount(email: email, token: token);
      } else {
        _sessionToken = token;
        _sessionOwnerId = email.trim().toLowerCase();
        // Persist account without token so it appears in account list
        await _persistLoginAccount(email: email, token: '');
      }
      // Try to enrich account name
      try {
        final profile = await me();
        final n = profile?['name']?.toString();
        if (n != null && n.isNotEmpty) {
          await _updateAccountName(id: email, name: n);
        }
      } catch (_) {}
      return LoginResult(success: true, accessToken: token);
    }

    String? errorMsg;
    try {
      final data = _decodeJson(resp.body);
      errorMsg = (data['error_description'] ?? data['message'] ?? data['error'])
          ?.toString();
    } catch (_) {}
    return LoginResult(
      success: false,
      message: errorMsg ?? 'Lỗi đăng nhập (${resp.statusCode})',
    );
  }

  Future<LoginResult> _loginWithSimpleEndpoint({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final uri = _uri(AppConfig.simpleLoginEndpoint);
    final body = {'email': email, 'password': password};

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      return LoginResult(success: false, message: _friendlyNetworkError(e));
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _decodeJson(resp.body);
      final token = (data['access_token'] ?? data['token'])?.toString();
      if (token == null || token.isEmpty) {
        return LoginResult(
          success: false,
          message: 'Thiếu token trong phản hồi',
        );
      }
      if (remember) {
        await _persistLoginAccount(email: email, token: token);
      } else {
        _sessionToken = token;
        _sessionOwnerId = email.trim().toLowerCase();
        // Persist account without token so it appears in account list
        await _persistLoginAccount(email: email, token: '');
      }
      try {
        final profile = await me();
        final n = profile?['name']?.toString();
        if (n != null && n.isNotEmpty) {
          await _updateAccountName(id: email, name: n);
        }
      } catch (_) {}
      return LoginResult(success: true, accessToken: token);
    }

    String? errorMsg;
    try {
      final data = _decodeJson(resp.body);
      errorMsg = data['message']?.toString();
    } catch (_) {}
    return LoginResult(
      success: false,
      message: errorMsg ?? 'Lỗi đăng nhập (${resp.statusCode})',
    );
  }

  // ---- Multi-account storage helpers ----
  Future<List<AccountInfo>> _getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('accounts');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list
          .map((e) => AccountInfo.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _setAccounts(List<AccountInfo> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(accounts.map((e) => e.toJson()).toList());
    await prefs.setString('accounts', raw);
  }

  Future<String?> _getActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_account_id');
  }

  Future<void> _setActiveId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove('active_account_id');
      await prefs.remove('access_token');
    } else {
      await prefs.setString('active_account_id', id);
      // keep legacy key in sync for existing code paths
      final acc = (await _getAccounts())
          .where((a) => a.id == id)
          .cast<AccountInfo?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (acc != null) {
        await prefs.setString('access_token', acc.token);
      }
    }
  }

  Future<void> _syncLegacyAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final id = await _getActiveId();
    if (id == null) {
      await prefs.remove('access_token');
      return;
    }
    final acc = (await _getAccounts()).firstWhere(
      (a) => a.id == id,
      orElse: () => AccountInfo(id: id, email: id, token: ''),
    );
    if (acc.token.isNotEmpty) {
      await prefs.setString('access_token', acc.token);
    } else {
      await prefs.remove('access_token');
    }
  }

  Future<void> _persistLoginAccount({
    required String email,
    required String token,
  }) async {
    final id = email.trim().toLowerCase();
    final accounts = await _getAccounts();
    final idx = accounts.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      accounts[idx] = accounts[idx].copyWith(token: token, email: email);
    } else {
      accounts.add(AccountInfo(id: id, email: email, token: token));
    }
    await _setAccounts(accounts);
    await _setActiveId(id);
    await _syncLegacyAccessToken();
  }

  Future<void> _updateAccountName({
    required String id,
    required String name,
  }) async {
    final accounts = await _getAccounts();
    final idx = accounts.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      accounts[idx] = accounts[idx].copyWith(name: name);
      await _setAccounts(accounts);
    }
  }

  // Refresh local account cache (e.g., display name) from backend profile
  Future<void> refreshLocalProfileCache() async {
    final id = await _getActiveId();
    if (id == null) return;
    try {
      final profile = await me();
      final n = profile?['name']?.toString();
      if (n != null && n.isNotEmpty) {
        await _updateAccountName(id: id, name: n);
      }
      // Notify listeners (e.g., HomePage) that profile data may have changed
      notifyListeners();
    } catch (_) {}
  }

  // Clears the persisted token for the currently active account if it exists,
  // but keeps the current session alive by moving the token into memory.
  Future<void> clearSavedTokenForActiveAccount() async {
    final id = await _getActiveId();
    if (id == null) return;
    final accounts = await _getAccounts();
    final idx = accounts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final acc = accounts[idx];
    if (acc.token.isEmpty) return; // Nothing to clear
    // Keep session alive in-memory for the rest of the run
    _sessionToken = acc.token;
    _sessionOwnerId = acc.id;
    // Remove persisted token
    accounts[idx] = acc.copyWith(token: '');
    await _setAccounts(accounts);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<void> setActiveAccount(String id) async {
    final accounts = await _getAccounts();
    final exists = accounts.any((a) => a.id == id);
    await _setActiveId(exists ? id : null);
    await _syncLegacyAccessToken();
    if (_sessionOwnerId != null && _sessionOwnerId != id) {
      _sessionToken = null;
      _sessionOwnerId = null;
    }
  }

  Future<List<AccountInfo>> getAccounts() => _getAccounts();

  Future<AccountInfo?> getActiveAccount() async {
    final id = await _getActiveId();
    if (id == null) return null;
    final accounts = await _getAccounts();
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    // Local logout: end current session only. Keep stored tokens
    // so user can quickly switch back without retyping credentials.
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = null; // clear in-memory session token
    _sessionOwnerId = null;
    await _setActiveId(null);
    await prefs.remove('access_token');
  }

  Future<void> removeAccount(String id) async {
    final active = await _getActiveId();
    if (active == id) {
      await logout();
      return;
    }
    final accounts = await _getAccounts();
    accounts.removeWhere((a) => a.id == id);
    await _setAccounts(accounts);
  }

  Future<void> logoutServer() async {
    final token = await getToken();
    if (token == null) {
      await logout();
      return;
    }
    try {
      final uri = _uri('/api/logout');
      await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    await logout();
  }

  // Permanently deletes the current user's account on the backend.
  // On success, removes the local account and logs out.
  Future<bool> deleteAccountPermanently() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    final active = await getActiveAccount();
    http.Response resp;
    try {
      final uri = _uri('/api/user');
      resp = await http
          .delete(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return false;
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (active != null) {
        // Remove from local multi-account store
        final accounts = await _getAccounts();
        accounts.removeWhere((a) => a.id == active.id);
        await _setAccounts(accounts);
      }
      await logout();
      return true;
    }
    return false;
  }

  Future<String?> getToken() async {
    final active = await getActiveAccount();
    if (_sessionToken != null &&
        _sessionToken!.isNotEmpty &&
        active != null &&
        active.id == _sessionOwnerId) {
      return _sessionToken;
    }
    final acc = await getActiveAccount();
    if (acc != null && acc.token.isNotEmpty) return acc.token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, dynamic>?> me() async {
    final token = await getToken();
    if (token == null) return null;
    final uri = _uri('/api/user');
    final resp = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _decodeJson(resp.body);
      final g = data['gender']?.toString();
      if (g != null) {
        final copy = Map<String, dynamic>.from(data);
        copy['gender'] = _toEnglishGender(g);
        return copy;
      }
      return data;
    }
    throw Exception('Lỗi tải thông tin (${resp.statusCode})');
  }

  // Public helper: returns the ID (email lowercase) of the currently active session.
  // Prefers in-memory session owner (non-remembered logins), falls back to persisted active account.
  Future<String?> getCurrentActiveId() async {
    if (_sessionOwnerId != null && _sessionOwnerId!.isNotEmpty) {
      return _sessionOwnerId;
    }
    return _getActiveId();
  }

  Future<LoginResult> updateProfile({
    required String name,
    required String phone,
    DateTime? dob,
    String? gender,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return LoginResult(success: false, message: 'Not logged in');
    }
    final uri = _uri('/api/user');
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      if (dob != null) 'dob': _isoDate(dob),
      if (gender != null) 'gender': _toEnglishGender(gender),
    };
    http.Response resp;
    try {
      resp = await http
          .put(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      return LoginResult(success: false, message: _friendlyNetworkError(e));
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return LoginResult(success: true);
    }
    try {
      final data = _decodeJson(resp.body);
      final message = data['message']?.toString();
      return LoginResult(
        success: false,
        message: message ?? 'Update failed (${resp.statusCode})',
      );
    } catch (_) {
      return LoginResult(
        success: false,
        message: 'Update failed (${resp.statusCode})',
      );
    }
  }

  Future<LoginResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return LoginResult(success: false, message: 'Not logged in');
    }
    final uri = _uri('/api/change-password');
    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'password': newPassword,
              'password_confirmation': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      return LoginResult(success: false, message: _friendlyNetworkError(e));
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final data = _decodeJson(resp.body);
        final msg = data['message']?.toString();
        return LoginResult(success: true, message: msg);
      } catch (_) {
        return LoginResult(success: true);
      }
    }

    try {
      final data = _decodeJson(resp.body);
      final message = data['message']?.toString();
      return LoginResult(
        success: false,
        message: message ?? 'Change password failed (${resp.statusCode})',
      );
    } catch (_) {
      return LoginResult(
        success: false,
        message: 'Change password failed (${resp.statusCode})',
      );
    }
  }

  String _friendlyNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('ECONNREFUSED') || s.contains('Connection refused')) {
      return 'Không thể kết nối máy chủ (ECONNREFUSED). Kiểm tra API base URL và backend đang chạy.';
    }
    if (s.contains('Failed host lookup') || s.contains('ENOTFOUND')) {
      return 'Không phân giải được tên máy chủ. Kiểm tra API base URL.';
    }
    if (s.contains('HandshakeException') ||
        s.contains('CERTIFICATE_VERIFY_FAILED')) {
      return 'Lỗi chứng chỉ SSL. Dùng HTTP hoặc cấu hình chứng chỉ khi test nội bộ.';
    }
    if (s.contains('TimeoutException') || s.contains('timed out')) {
      return 'Kết nối hết thời gian chờ. Kiểm tra mạng hoặc server.';
    }
    return 'Không thể kết nối máy chủ.';
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
