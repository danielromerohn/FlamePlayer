import 'dart:convert';
import 'package:http/http.dart' as http;

class LibraryService {
  static Future<List<dynamic>> getUserViews({
    required String serverUrl,
    required String token,
    required String userId,
  }) async {
    final url = "$serverUrl/Users/$userId/Views";

    final res = await http.get(
      Uri.parse(url),
      headers: {"X-Emby-Token": token},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data["Items"] ?? [];
    }

    return [];
  }
}
