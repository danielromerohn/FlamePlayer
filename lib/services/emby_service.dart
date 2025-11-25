// lib/services/emby_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class EmbyService {

  // -------------------------------------------------------------
  // GET ITEM INFO
  // -------------------------------------------------------------
  static Future<Map<String, dynamic>?> getItemInfo({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
    String fields =
    'MediaSources,Path,Overview,Genres,People,RunTimeTicks,PremiereDate,'
        'ProductionYear,ProviderIds,ParentId,SeriesId,SeasonId,IndexNumber,'
        'ImageTags,BackdropImageTags,Taglines,UserData,RemoteTrailers,LocalTrailerCount',
  }) async {
    try {
      final url = "$serverUrl/Users/$userId/Items/$itemId?Fields=$fields";

      final res = await http.get(
        Uri.parse(url),
        headers: {"X-Emby-Token": token},
      );

      if (res.statusCode != 200) {
        print("getItemInfo ERROR: ${res.statusCode} ${res.body}");
        return null;
      }

      return jsonDecode(res.body);
    } catch (e) {
      print("getItemInfo exception: $e");
      return null;
    }
  }

  // -------------------------------------------------------------
  // CHILDREN
  // -------------------------------------------------------------
  static Future<List<dynamic>?> getChildren({
    required String serverUrl,
    required String token,
    required String userId,
    required String parentId,
    String includeItemTypes = '',
    bool recursive = false,
    String fields =
    'MediaSources,Path,Container,Type,Name,Id,IndexNumber,SeriesId,SeasonId,'
        'ImageTags,PrimaryImageAspectRatio,DateCreated',
  }) async {
    try {
      final rec = recursive ? '&Recursive=true' : '';
      final types = includeItemTypes.isNotEmpty
          ? '&IncludeItemTypes=$includeItemTypes'
          : '';

      final url =
          "$serverUrl/Users/$userId/Items?ParentId=$parentId$rec&Fields=$fields$types";

      final res = await http.get(
        Uri.parse(url),
        headers: {"X-Emby-Token": token},
      );

      if (res.statusCode != 200) {
        print("getChildren ERROR: ${res.statusCode} ${res.body}");
        return null;
      }

      return (jsonDecode(res.body)['Items'] as List?) ?? [];
    } catch (e) {
      print("getChildren exception: $e");
      return null;
    }
  }

  // -------------------------------------------------------------
  // GET PLAYABLE PATH RECURSIVELY
  // -------------------------------------------------------------
  static Future<String?> getPlayablePathRecursive({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
    int depthLimit = 6,
  }) async {
    if (depthLimit <= 0) return null;

    try {
      final item = await getItemInfo(
        serverUrl: serverUrl,
        token: token,
        userId: userId,
        itemId: itemId,
      );

      if (item == null) return null;

      final isFolder = item['IsFolder'] == true ||
          item['Type']?.toString().toLowerCase() == 'folder';

      // Si NO es carpeta, devolver Path
      if (!isFolder) {
        if (item['MediaSources'] != null &&
            item['MediaSources'].isNotEmpty &&
            item['MediaSources'][0]['Path'] != null) {
          return item['MediaSources'][0]['Path'];
        }

        if (item['Path'] != null) return item['Path'];
      }

      // Si es carpeta, buscar entre hijos
      final children = await getChildren(
        serverUrl: serverUrl,
        token: token,
        userId: userId,
        parentId: itemId,
      );

      if (children == null || children.isEmpty) return null;

      for (final c in children) {
        if (c['MediaSources'] != null &&
            c['MediaSources'].isNotEmpty &&
            c['MediaSources'][0]['Path'] != null) {
          return c['MediaSources'][0]['Path'];
        }
        if (c['Path'] != null) return c['Path'];
      }

      // Recursivo
      for (final c in children) {
        final id = c['Id']?.toString();
        if (id == null) continue;

        final found = await getPlayablePathRecursive(
          serverUrl: serverUrl,
          token: token,
          userId: userId,
          itemId: id,
          depthLimit: depthLimit - 1,
        );

        if (found != null) return found;
      }

      return null;
    } catch (e) {
      print("getPlayablePathRecursive ERROR: $e");
      return null;
    }
  }

  // -------------------------------------------------------------
  // MARK PLAYED / UNPLAYED
  // -------------------------------------------------------------
  static Future<bool> markPlayed({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
  }) async {
    final res = await http.post(
      Uri.parse("$serverUrl/Users/$userId/PlayedItems/$itemId"),
      headers: {"X-Emby-Token": token},
    );
    return res.statusCode == 200;
  }

  static Future<bool> unmarkPlayed({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
  }) async {
    final res = await http.delete(
      Uri.parse("$serverUrl/Users/$userId/PlayedItems/$itemId"),
      headers: {"X-Emby-Token": token},
    );
    return res.statusCode == 200;
  }

  // -------------------------------------------------------------
  // FAVORITES
  // -------------------------------------------------------------
  static Future<bool> markFavorite({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
  }) async {
    final res = await http.post(
      Uri.parse("$serverUrl/Users/$userId/FavoriteItems/$itemId"),
      headers: {"X-Emby-Token": token},
    );
    return res.statusCode == 200;
  }

  static Future<bool> unmarkFavorite({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
  }) async {
    final res = await http.delete(
      Uri.parse("$serverUrl/Users/$userId/FavoriteItems/$itemId"),
      headers: {"X-Emby-Token": token},
    );
    return res.statusCode == 200;
  }

  // -------------------------------------------------------------
  // SUBTÍTULOS
  // -------------------------------------------------------------
  static Future<Map<String, dynamic>?> getVideoAndSubtitleInfo({
    required String serverUrl,
    required String token,
    required String userId,
    required String itemId,
  }) async {
    final item = await getItemInfo(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
      itemId: itemId,
    );

    if (item == null) return null;

    final ms = item["MediaSources"];
    if (ms == null || ms.isEmpty) return null;

    final source = ms[0];
    final mediaSourceId = source["Id"]?.toString();

    if (mediaSourceId == null) return null;

    final streams = (source["MediaStreams"] as List?) ?? [];

    final subs = streams
        .where((s) => s["Type"] == "Subtitle" && s["IsTextSubtitleStream"] == true)
        .toList();

    if (subs.isEmpty) {
      return {"mediaSourceId": mediaSourceId, "subtitleUrl": null};
    }

    Map? forced = subs.firstWhere(
          (s) => s["IsForced"] == true,
      orElse: () => null,
    );

    final selected = forced ?? subs.first;
    final index = selected["Index"];
    final codec = (selected["Codec"] ?? "srt").toString();
    final ext = codec == "subrip" ? "srt" : codec;

    final subtitleUrl =
        "$serverUrl/Videos/$itemId/$mediaSourceId/Subtitles/$index/Stream.$ext?api_key=$token";

    return {
      "mediaSourceId": mediaSourceId,
      "subtitleUrl": subtitleUrl,
    };
  }

  // -------------------------------------------------------------
  // URL DE IMAGEN
  // -------------------------------------------------------------
  static String imageUrl({
    required String serverUrl,
    required String itemId,
    required String imageTag,
    int maxWidth = 800,
    String apiKeyParam = '',
  }) {
    final q = apiKeyParam.isNotEmpty ? '&api_key=$apiKeyParam' : '';
    return "$serverUrl/Items/$itemId/Images/Primary?tag=$imageTag&maxWidth=$maxWidth$q";
  }

  // -------------------------------------------------------------
  // LOCAL TRAILERS (API oficial)
  // -------------------------------------------------------------
  static Future<List<dynamic>> getLocalTrailers({
    required String serverUrl,
    required String token,
    required String itemId,
  }) async {
    try {
      final url = "$serverUrl/Items/$itemId/LocalTrailers";

      final res = await http.get(
        Uri.parse(url),
        headers: {"X-Emby-Token": token},
      );

      if (res.statusCode != 200) return [];

      return (jsonDecode(res.body)["Items"] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  // -------------------------------------------------------------
  // BUSCAR SOLO "trailer.strm" en el directorio de la película
  // -------------------------------------------------------------
  static Future<String?> findLocalTrailerStrm({
    required String serverUrl,
    required String token,
    required String parentId,
  }) async {
    final url = Uri.parse(
      "$serverUrl/Items?ParentId=$parentId&IncludeItemTypes=Video&Recursive=true&Fields=Path,Name&X-Emby-Token=$token",
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      print("Error al listar directorio: ${res.body}");
      return null;
    }

    final items = (jsonDecode(res.body)["Items"] as List?) ?? [];

    for (final item in items) {
      final name = item["Name"]?.toString().toLowerCase() ?? "";
      final path = item["Path"]?.toString().toLowerCase() ?? "";

      // Detectar EXACTAMENTE trailer.strm
      if (name == "trailer.strm" || path.endsWith("/trailer.strm")) {
        print("🎬 Trailer.strm encontrado -> ${item["Id"]}");
        return item["Id"].toString();
      }
    }

    print("❌ No se encontró trailer.strm");
    return null;
  }

  // -------------------------------------------------------------
  // GET USER INFO
  // -------------------------------------------------------------
  static Future<Map<String, dynamic>?> getUserInfo({
    required String serverUrl,
    required String token,
    required String userId,
  }) async {
    try {
      final res = await http.get(
        Uri.parse("$serverUrl/Users/$userId"),
        headers: {"X-Emby-Token": token},
      );

      if (res.statusCode != 200) return null;

      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }
}
