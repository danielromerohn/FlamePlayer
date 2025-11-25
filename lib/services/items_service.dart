// lib/services/items_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ItemsService {
  static Future<List<dynamic>> getItems({
    required String serverUrl,
    required String token,
    required String userId,
    required String parentId,

    /// Movie, Series, BoxSet…
    String includeItemTypes = "",
  }) async {
    try {
      // Si es película, activamos búsqueda recursiva
      String recursive = "";
      if (includeItemTypes == "Movie") {
        recursive = "&Recursive=true";
      }

      // Filtro por tipo de item
      String types = includeItemTypes.isNotEmpty
          ? "&IncludeItemTypes=$includeItemTypes"
          : "";

      // Ordenar por fecha agregada, más reciente primero
      const String sort = "&SortBy=DateCreated&SortOrder=Descending";

      // Importante: pedir campos útiles para UI posterior (poster, path, etc.)
      const String fields =
          "&Fields=PrimaryImageAspectRatio,CanPlay,MediaSources,ImageTags,Type,Name,Path,DateCreated";

      final url =
          "$serverUrl/Users/$userId/Items?ParentId=$parentId$recursive$types$sort$fields";

      final res = await http.get(
        Uri.parse(url),
        headers: {"X-Emby-Token": token},
      );

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data["Items"] ?? [];
    } catch (e) {
      print("ItemsService.getItems ERROR: $e");
      return [];
    }
  }
}
