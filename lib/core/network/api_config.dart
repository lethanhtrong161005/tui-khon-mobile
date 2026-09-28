/// API Configuration for Túi Khôn Flutter Mobile App
/// 
/// Contains environment base URLs, timeout intervals, standard endpoints,
/// and default request headers.

enum ApiEnvironment { development, staging, production, mock }

class ApiConfig {
  static ApiEnvironment currentEnv = ApiEnvironment.development;

  static String get baseUrl {
    switch (currentEnv) {
      case ApiEnvironment.production:
        return 'https://api.tuikhon.vn/v1';
      case ApiEnvironment.staging:
        return 'https://api-staging.tuikhon.vn/v1';
      case ApiEnvironment.mock:
        return 'https://mock.tuikhon.local/v1';
      case ApiEnvironment.development:
      default:
        return 'https://api-dev.tuikhon.vn/v1';
    }
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration aiTimeout = Duration(seconds: 40);

  // Retry settings
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 1000);

  // Endpoints
  static const String authLogin = '/auth/login';
  static const String authLogout = '/auth/logout';
  static const String authRefreshToken = '/auth/refresh-token';
  static const String authProfile = '/auth/me';

  static const String transactions = '/transactions';
  static String transactionDetail(String id) => '/transactions/$id';
  static const String scanReceipt = '/transactions/scan-receipt';

  static const String splitBillGroups = '/split-bill/groups';
  static String splitBillGroup(String id) => '/split-bill/groups/$id';
  static const String vietQrGenerate = '/split-bill/vietqr/generate';

  static const String aiParseQuickRecord = '/ai/parse-quick-record';
  static const String aiForecast = '/ai/forecast';
  static const String aiAdvice = '/ai/advice';

  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
}
