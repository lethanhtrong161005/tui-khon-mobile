import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

class ProfileSession {
  static String? accessToken;
  static String? refreshToken;

  static bool get isAuthenticated {
    return accessToken != null && accessToken!.isNotEmpty;
  }

  static void setTokens({required String access, required String refresh}) {
    accessToken = access;
    refreshToken = refresh;
  }

  static void clear() {
    accessToken = null;
    refreshToken = null;
  }
}

class UserProfile {
  final String userId;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? phoneNumber;

  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.phoneNumber,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'phoneNumber': phoneNumber,
    };
  }
}

class ProfileRepository {
  static const String _localProfileKey = 'local_user_profile';

  final MobileApiClient _api = MobileApiClient();

  Map<String, dynamic> _responseData(dynamic raw) {
    final envelope = Map<String, dynamic>.from(raw as Map);
    final data = envelope['data'];

    if (data is! Map) {
      throw const FormatException(
        'Phản hồi Profile không chứa dữ liệu hợp lệ.',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  Future<UserProfile> getProfile() async {
    if (!ProfileSession.isAuthenticated) {
      return _getLocalProfile();
    }

    _api.setAuthToken(ProfileSession.accessToken);

    final raw = await _api.request(path: '/auth/me', method: 'GET');

    return UserProfile.fromJson(_responseData(raw));
  }

  Future<UserProfile> updateProfile({
    required String displayName,
    required String phoneNumber,
    required String avatarUrl,
  }) async {
    if (!ProfileSession.isAuthenticated) {
      final current = await _getLocalProfile();

      final updated = UserProfile(
        userId: current.userId,
        email: current.email,
        displayName: displayName.trim(),
        phoneNumber: phoneNumber.trim(),
        avatarUrl: avatarUrl.trim().isEmpty ? null : avatarUrl.trim(),
      );

      await _saveLocalProfile(updated);
      return updated;
    }

    _api.setAuthToken(ProfileSession.accessToken);

    final raw = await _api.request(
      path: '/auth/me',
      method: 'PUT',
      body: {
        'displayName': displayName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'avatarUrl': avatarUrl.trim(),
      },
    );

    return UserProfile.fromJson(_responseData(raw));
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (oldPassword.isEmpty) {
      throw ArgumentError('Vui lòng nhập mật khẩu hiện tại.');
    }

    if (newPassword.length < 6) {
      throw ArgumentError('Mật khẩu mới phải có ít nhất 6 ký tự.');
    }

    if (newPassword != confirmPassword) {
      throw ArgumentError('Mật khẩu xác nhận không khớp.');
    }

    if (!ProfileSession.isAuthenticated) {
      // Chế độ chạy độc lập của PRM-4.
      // Không lưu mật khẩu vào SharedPreferences.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return;
    }

    _api.setAuthToken(ProfileSession.accessToken);

    await _api.request(
      path: '/auth/change-password',
      method: 'PUT',
      body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<void> logout() async {
    final accessToken = ProfileSession.accessToken;
    final refreshToken = ProfileSession.refreshToken;

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty) {
      _api.setAuthToken(accessToken);

      await _api.request(
        path: '/auth/logout',
        method: 'POST',
        body: {'refreshToken': refreshToken},
      );
    }

    ProfileSession.clear();
  }

  Future<UserProfile> _getLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProfile = prefs.getString(_localProfileKey);

    if (savedProfile == null || savedProfile.isEmpty) {
      const defaultProfile = UserProfile(
        userId: 'local-user',
        email: 'tuikhon@gmail.com',
        displayName: 'Túi Khôn',
        phoneNumber: '0987123456',
      );

      await _saveLocalProfile(defaultProfile);
      return defaultProfile;
    }

    try {
      final json = jsonDecode(savedProfile);
      return UserProfile.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (_) {
      await prefs.remove(_localProfileKey);
      return _getLocalProfile();
    }
  }

  Future<void> _saveLocalProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_localProfileKey, jsonEncode(profile.toJson()));
  }
}
