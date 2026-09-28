/// Standardized API Exceptions and Vietnamese Error Messages for Flutter

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final String userMessage;
  final dynamic details;
  final bool isRetryable;

  ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    String? userMessage,
    this.details,
    bool? isRetryable,
  })  : userMessage = userMessage ?? _resolveUserMessage(statusCode, errorCode),
        isRetryable = isRetryable ?? _resolveRetryable(statusCode);

  static bool _resolveRetryable(int? status) {
    if (status == null || status == 0) return true;
    return [408, 429, 500, 502, 503, 504].contains(status);
  }

  static String _resolveUserMessage(int? status, String? code) {
    if (status == 0 || code == 'ERR_NETWORK') {
      return 'Không có kết nối mạng. Ứng dụng đang hoạt động ở chế độ ngoại tuyến.';
    }
    if (status == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (status == 403) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (status == 404) {
      return 'Dữ liệu không tồn tại trên hệ thống.';
    }
    if (status == 422) {
      return 'Dữ liệu gửi lên không đúng định dạng.';
    }
    if (status == 429) {
      return 'Thao tác quá nhanh. Vui lòng đợi trong giây lát.';
    }
    if (status != null && status >= 500) {
      return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
    }
    return 'Đã xảy ra lỗi kết nối. Vui lòng thử lại.';
  }

  @override
  String toString() => 'ApiException(status: $statusCode, code: $errorCode, message: $userMessage)';
}
