import 'package:http/http.dart' as http;

class ServerService {
  // Verificar si el servidor responde correctamente
  Future<bool> testServer(String url) async {
    try {
      final res = await http.get(Uri.parse("$url/System/Info/Public"));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
