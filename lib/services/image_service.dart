// lib/services/image_service.dart

class ImageService {
  /// Normaliza la URL (elimina "/" final)
  static String _base(String serverUrl) {
    return serverUrl.replaceAll(RegExp(r'\/$'), '');
  }

  /// --------------------------------------------------------------
  ///  POSTER (Primary)
  ///  Se usa en MovieDetailScreen y SeriesDetailScreen
  ///
  ///  Formato basado en tu implementación real:
  ///  /Items/{itemId}/Images/Primary?maxWidth=800&quality=90&tag=XXXX&api_key=TOKEN
  /// --------------------------------------------------------------
  static String poster(
      String serverUrl,
      String itemId, {
        String? tag,
        int maxWidth = 800,
        int quality = 90,
        String? apiKey,
      }) {
    final base = _base(serverUrl);

    String url =
        "$base/Items/$itemId/Images/Primary?maxWidth=$maxWidth&quality=$quality";

    if (tag != null) url += "&tag=$tag";
    if (apiKey != null) url += "&api_key=$apiKey";

    return url;
  }

  /// --------------------------------------------------------------
  ///  BACKDROP (Background)
  ///  Usado en SeriesDetailScreen para el header
  ///
  ///  /Items/{itemId}/Images/Backdrop?maxWidth=1600&quality=90&tag=XXXX&api_key=TOKEN
  /// --------------------------------------------------------------
  static String backdrop(
      String serverUrl,
      String itemId, {
        String? tag,
        int maxWidth = 1600,
        int quality = 90,
        String? apiKey,
      }) {
    final base = _base(serverUrl);

    String url =
        "$base/Items/$itemId/Images/Backdrop?maxWidth=$maxWidth&quality=$quality";

    if (tag != null) url += "&tag=$tag";
    if (apiKey != null) url += "&api_key=$apiKey";

    return url;
  }

  /// --------------------------------------------------------------
  ///  EPISODE THUMBNAIL
  ///
  ///  Usado en Season → Episode list (SeriesDetailScreen)
  ///  /Items/{id}/Images/Primary?maxWidth=400&quality=90&tag=XXXX&api_key=TOKEN
  /// --------------------------------------------------------------
  static String episodeThumb(
      String serverUrl,
      String itemId, {
        String? tag,
        int maxWidth = 400,
        int quality = 90,
        String? apiKey,
      }) {
    return poster(
      serverUrl,
      itemId,
      tag: tag,
      maxWidth: maxWidth,
      quality: quality,
      apiKey: apiKey,
    );
  }

  /// --------------------------------------------------------------
  ///  PERSON / ACTOR IMAGE
  ///
  ///  IMPORTANTE: MovieDetailScreen usa manualmente:
  ///     /emby/Items/{actorId}/Images/Primary?maxWidth=300&quality=90&api_key=TOKEN&tag=TAG
  ///
  ///  Lo replicamos EXACTAMENTE, incluyendo el "/emby".
  /// --------------------------------------------------------------
  static String person(
      String serverUrl,
      String actorId,
      String apiKey, {
        String? tag,
        int maxWidth = 300,
        int quality = 90,
      }) {
    final base = _base(serverUrl);

    String url =
        "$base/emby/Items/$actorId/Images/Primary?maxWidth=$maxWidth&quality=$quality&api_key=$apiKey";

    if (tag != null) url += "&tag=$tag";

    return url;
  }

  /// --------------------------------------------------------------
  ///  USER AVATAR
  ///
  ///  Usado en HomeScreen:
  ///     /Users/{userId}/Images/Primary
  ///
  ///  No usa tag ni quality.
  /// --------------------------------------------------------------
  static String userAvatar(
      String serverUrl,
      String userId,
      ) {
    final base = _base(serverUrl);
    return "$base/Users/$userId/Images/Primary";
  }

  /// --------------------------------------------------------------
  ///  URL GENÉRICA (por si la necesitas)
  ///  Respeta tu método original EmbyService.imageUrl()
  ///
  ///  /Items/{itemId}/Images/Primary?maxWidth=800&api_key=TOKEN
  /// --------------------------------------------------------------
  static String basicPrimary(
      String serverUrl,
      String itemId, {
        int maxWidth = 800,
        String? apiKey,
      }) {
    final base = _base(serverUrl);

    String url =
        "$base/Items/$itemId/Images/Primary?maxWidth=$maxWidth";

    if (apiKey != null) url += "&api_key=$apiKey";

    return url;
  }
}
