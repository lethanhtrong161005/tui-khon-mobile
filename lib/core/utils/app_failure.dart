// Domain failures carry a stable code; presentation supplies the language.
// The original message preserves diagnostics and compatibility for non-UI callers.
abstract interface class CodedFailure {
  String get code;
  List<String> get arguments;
}

class AppFailure extends StateError implements CodedFailure {
  AppFailure(this.code, this.arguments, String diagnostic) : super(diagnostic);
  @override
  final String code;
  @override
  final List<String> arguments;
}

class AppFormatFailure extends FormatException implements CodedFailure {
  AppFormatFailure(this.code, this.arguments, String diagnostic)
      : super(diagnostic);
  @override
  final String code;
  @override
  final List<String> arguments;
}

class AppArgumentFailure extends ArgumentError implements CodedFailure {
  AppArgumentFailure(this.code, this.arguments, String diagnostic)
      : super(diagnostic);
  @override
  final String code;
  @override
  final List<String> arguments;
}
