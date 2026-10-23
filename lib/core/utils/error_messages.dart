import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts backend / platform exceptions into short Vietnamese messages for SnackBars.
String friendlyError(Object error) {
  if (error is AuthException) return _authMessage(error);

  if (error is FunctionException) {
    // Edge Functions reply with { success: false, error: { code, message } }
    final details = error.details;
    if (details is Map && details['error'] is Map && details['error']['message'] is String) {
      return details['error']['message'] as String;
    }
    if (error.status == 404) return 'Tính năng AI chưa được bật trên server';
    return 'AI tạm thời không phản hồi, vui lòng thử lại';
  }

  if (error is PostgrestException) {
    if (error.code == '23505') return 'Dữ liệu này đã tồn tại';
    if (error.code == '42501') return 'Bạn không có quyền thực hiện thao tác này';
    return 'Không thể lưu dữ liệu, vui lòng thử lại';
  }

  if (error is GoogleSignInException) {
    if (error.code == GoogleSignInExceptionCode.canceled) return 'Bạn đã huỷ đăng nhập Google';
    if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
      return 'Đăng nhập Google chưa được cấu hình cho ứng dụng';
    }
    return 'Không thể đăng nhập Google, vui lòng thử lại';
  }

  if (error is SocketException || error is TimeoutException) {
    return 'Không có kết nối mạng, vui lòng kiểm tra lại';
  }

  if (error is StateError) return error.message;

  return 'Có lỗi xảy ra, vui lòng thử lại';
}

String _authMessage(AuthException e) {
  if (e is AuthRetryableFetchException) return 'Không có kết nối mạng, vui lòng kiểm tra lại';

  switch (e.code) {
    case 'invalid_credentials':
      return 'Email hoặc mật khẩu không đúng';
    case 'email_not_confirmed':
      return 'Email chưa được xác thực';
    case 'user_already_exists':
    case 'email_exists':
      return 'Email này đã được đăng ký, hãy đăng nhập';
    case 'otp_expired':
      return 'Mã xác thực sai hoặc đã hết hạn';
    case 'weak_password':
      return 'Mật khẩu quá yếu, hãy dùng ít nhất 6 ký tự';
    case 'same_password':
      return 'Mật khẩu mới phải khác mật khẩu cũ';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Bạn thao tác quá nhanh, vui lòng đợi một lát rồi thử lại';
    case 'user_banned':
      return 'Tài khoản của bạn đã bị khoá';
    case 'email_address_invalid':
    case 'validation_failed':
      return 'Email không hợp lệ';
  }
  if (e.statusCode == '429') return 'Bạn thao tác quá nhanh, vui lòng đợi một lát rồi thử lại';
  return 'Không thể xác thực, vui lòng thử lại';
}
