import 'dart:developer' as developer;

class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: scope, error: error, stackTrace: stackTrace);
  }

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: scope,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
