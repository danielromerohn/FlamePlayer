import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static Future<Map<String, dynamic>?> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {

    // Header obligatorio para Emby:
    final authHeader =
        'MediaBrowser Client="FlamePlayer", Device="FlutterApp", DeviceId="flame123", Version="1.0.0"';

    try {
      final response = await http.post(
        Uri.parse("$serverUrl/Users/AuthenticateByName"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-Emby-Authorization": authHeader,  // ← AQUI LA MAGIA
        },
        body: jsonEncode({
          "Username": username,
          "Pw": password,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Login exception: $e");
    }

    return null;
  }
}
