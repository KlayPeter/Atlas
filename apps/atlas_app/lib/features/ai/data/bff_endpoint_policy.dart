String validateBffUrl(String value) {
  final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const FormatException('Atlas BFF 地址格式无效');
  }
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    throw const FormatException('Atlas BFF 地址不能包含账号、查询参数或片段');
  }

  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLoopback)) {
    throw const FormatException('非本机 Atlas BFF 必须使用 HTTPS');
  }
  return normalized;
}
