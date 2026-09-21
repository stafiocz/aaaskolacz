import 'package:http/http.dart' as http;

class MobileClient extends http.BaseClient {
  MobileClient({
    required this.base,
    required this.readToken,
    required this.clearToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final Uri base;
  final Future<String?> Function() readToken;
  final Future<void> Function() clearToken;
  final http.Client _client;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != base.origin) {
      throw StateError('Unexpected API origin');
    }
    request.followRedirects = false;
    final token = await readToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final response = await _client.send(request);
    if (request.url.path == '/api/logout' && response.statusCode == 204) {
      await clearToken();
    }
    return response;
  }

  @override
  void close() => _client.close();
}
