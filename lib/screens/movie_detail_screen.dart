// lib/screens/movie_detail_screen.dart
import 'package:flutter/material.dart';

import '../services/emby_service.dart';
import '../services/image_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String token;
  final String userId;
  final String itemId;

  const MovieDetailScreen({
    super.key,
    required this.serverUrl,
    required this.token,
    required this.userId,
    required this.itemId,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Map<String, dynamic>? movie;
  bool loading = true;
  bool isPlayed = false;
  bool isFavorite = false;

  // Trailer detectado
  String? _localTrailerId;

  bool get _hasTrailer => _localTrailerId != null;

  @override
  void initState() {
    super.initState();
    loadMovie();
  }

  // ---------------------------------------------------------------------------
  // Cargar info del item + buscar trailer local
  // ---------------------------------------------------------------------------
  Future<void> loadMovie() async {
    final data = await EmbyService.getItemInfo(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: widget.itemId,
    );

    // 👇 ESTA VARIABLE DEBE ESTAR AQUÍ DEFINIDA
    String? localTrailerId;

    if (data != null) {
      // Intentar trailers locales usando el endpoint oficial
      try {
        final localTrailers = await EmbyService.getLocalTrailers(
          serverUrl: widget.serverUrl,
          token: widget.token,
          itemId: widget.itemId,
        );

        print("🎬 getLocalTrailers -> ${localTrailers.length} encontrados");

        if (localTrailers.isNotEmpty) {
          final first = localTrailers.first as Map<String, dynamic>;

          final tid = first["Id"]?.toString();
          if (tid != null && tid.isNotEmpty) {
            print("✅ Trailer local detectado: $tid");
            localTrailerId = tid;
          }
        } else {
          print("❌ No se detectó trailer local (Items vacío)");
        }
      } catch (e) {
        print("❌ Error en getLocalTrailers: $e");
      }
    }

    if (!mounted) return;

    setState(() {
      movie = data;
      loading = false;

      final userData = movie?["UserData"] ?? {};
      isPlayed = userData["Played"] == true;
      isFavorite = userData["IsFavorite"] == true;

      _localTrailerId = localTrailerId;   // 👈 AQUÍ YA NO FALLA
    });
  }

  // ---------------------------------------------------------------------------
  // Abrir Player para película
  // ---------------------------------------------------------------------------
  Future<void> _openPlayer({
    required String title,
    Duration? startPosition,
  }) async {
    final url = await EmbyService.getPlayablePathRecursive(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: widget.itemId,
    );

    final info = await EmbyService.getVideoAndSubtitleInfo(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: widget.itemId,
    );

    final subtitleUrl = info?["subtitleUrl"];

    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo reproducir")),
        );
      }
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          subtitleUrl: subtitleUrl,
          title: title,
          initialPosition: startPosition,
        ),
      ),
    );



  }



  // ---------------------------------------------------------------------------
  // Reproducir Trailer Local
  // ---------------------------------------------------------------------------
  Future<void> _playTrailer(String title) async {
    if (_localTrailerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay trailer disponible")),
      );
      return;
    }

    final url = await EmbyService.getPlayablePathRecursive(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: _localTrailerId!,
    );

    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo reproducir el trailer")),
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          subtitleUrl: null,
          title: "$title (Trailer)",
          initialPosition: null,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatear texto "Faltan 1h 05min"
  // ---------------------------------------------------------------------------
  String _formatRemaining(Duration d) {
    if (d.inMinutes <= 0) return "Quedan menos de 1 min";
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final mm = m.toString().padLeft(2, '0');
      return "Faltan ${h}h ${mm}min";
    }
    return "Faltan ${d.inMinutes}min";
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading || movie == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final m = movie!;
    final title = m["Name"] ?? "Sin título";
    final year  = m["ProductionYear"]?.toString() ?? "";
    final overview = m["Overview"] ?? "";
    final genres   = (m["Genres"] as List?)?.join(", ") ?? "";

    // Datos de reproducción
    final userData = m["UserData"] ?? {};
    final playbackTicks = userData["PlaybackPositionTicks"] ?? 0;
    final playedPct     = (userData["PlayedPercentage"] ?? 0).toDouble();

    final runTimeTicks = m["RunTimeTicks"];
    Duration? resumePosition;
    Duration? remaining;
    double watchedFraction = 0.0;

    if (playbackTicks is int && playbackTicks > 0) {
      resumePosition = Duration(milliseconds: (playbackTicks / 10000).round());
    }

    if (runTimeTicks is int) {
      final totalMs = (runTimeTicks / 10000).round();
      final total    = Duration(milliseconds: totalMs);
      final playedMs = (playbackTicks / 10000).round();
      final played   = Duration(milliseconds: playedMs);

      remaining = total - played;
      if (remaining.inMilliseconds < 0) remaining = Duration.zero;

      watchedFraction = (playbackTicks / runTimeTicks).clamp(0.0, 1.0);
    }

    // Poster
    final posterTag = m["ImageTags"]?["Primary"];
    final posterUrl = posterTag != null
        ? ImageService.poster(widget.serverUrl, widget.itemId, tag: posterTag)
        : null;

    // Backdrop
    final backdropTag = (m["BackdropImageTags"] is List &&
        m["BackdropImageTags"].isNotEmpty)
        ? m["BackdropImageTags"][0]
        : null;

    final backdropUrl = backdropTag != null
        ? ImageService.backdrop(widget.serverUrl, widget.itemId, tag: backdropTag)
        : null;

    // Tagline
    final tagline = (m["Taglines"] is List && m["Taglines"].isNotEmpty)
        ? m["Taglines"][0]
        : null;

    // Cast
    final List cast =
        (m["People"] as List?)?.where((p) => p["Type"] == "Actor").toList() ??
            [];

    final bool hasProgress = resumePosition != null;

    // -----------------------------------------------------------------------
    // UI
    // -----------------------------------------------------------------------
    return Scaffold(
      body: Stack(
        children: [
          // BACKDROP
          if (backdropUrl != null)
            Positioned.fill(
              child: Image.network(backdropUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),

          // DEGRADADO
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // CONTENIDO
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 320),

                // POSTER + INFO --------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (posterUrl != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                posterUrl,
                                width: 140,
                                height: 210,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                      width: 140,
                                      height: 210,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.movie,
                                          color: Colors.white70, size: 40),
                                    ),
                              ),
                            ),
                            if (playedPct > 0)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (playedPct / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE50914),
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 6),
                            Text(year,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                )),
                            if (genres.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  genres,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // PROGRESO ------------------------------------------------------
                if (hasProgress && remaining != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: watchedFraction,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatRemaining(remaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (hasProgress) const SizedBox(height: 20),

                // BOTONES PRINCIPALES ------------------------------------------
                if (!hasProgress) ...[
                  // Reproducir
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Reproducir"),
                      onPressed: () => _openPlayer(title: title),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_hasTrailer)
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const Icon(Icons.movie),
                        label: const Text("Trailer"),
                        onPressed: () => _playTrailer(title),
                      ),
                    ),

                  const SizedBox(height: 20),

                ] else ...[
                  // Reanudar
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Reanudar"),
                      onPressed: () => _openPlayer(
                        title: title,
                        startPosition: resumePosition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Restart
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text("Desde el principio"),
                      onPressed: () => _openPlayer(title: title),
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (_hasTrailer)
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const Icon(Icons.movie),
                        label: const Text("Trailer"),
                        onPressed: () => _playTrailer(title),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],

                // VISTO / MI LISTA ----------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Visto
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isPlayed ? Colors.white : Colors.grey.withOpacity(0.5),
                        foregroundColor:
                        isPlayed ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        if (!isPlayed) {
                          await EmbyService.markPlayed(
                            serverUrl: widget.serverUrl,
                            token: widget.token,
                            userId: widget.userId,
                            itemId: widget.itemId,
                          );
                        } else {
                          await EmbyService.unmarkPlayed(
                            serverUrl: widget.serverUrl,
                            token: widget.token,
                            userId: widget.userId,
                            itemId: widget.itemId,
                          );
                        }
                        setState(() => isPlayed = !isPlayed);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Visto"),
                    ),

                    const SizedBox(width: 12),

                    // Mi lista (favorito)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isFavorite ? Colors.white : Colors.grey.withOpacity(0.3),
                        foregroundColor:
                        isFavorite ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        if (!isFavorite) {
                          await EmbyService.markFavorite(
                            serverUrl: widget.serverUrl,
                            token: widget.token,
                            userId: widget.userId,
                            itemId: widget.itemId,
                          );
                        } else {
                          await EmbyService.unmarkFavorite(
                            serverUrl: widget.serverUrl,
                            token: widget.token,
                            userId: widget.userId,
                            itemId: widget.itemId,
                          );
                        }
                        setState(() => isFavorite = !isFavorite);
                      },
                      icon: Icon(isFavorite ? Icons.check : Icons.add),
                      label:
                      Text(isFavorite ? "✓ En mi lista" : "+ Mi lista"),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // TAGLINE --------------------------------------------------------
                if (tagline != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tagline,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // OVERVIEW -------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    overview,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // REPARTO --------------------------------------------------------
                if (cast.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Reparto",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),

                if (cast.isNotEmpty)
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cast.length,
                      itemBuilder: (_, i) {
                        final actor = cast[i];
                        final actorId = actor["Id"];
                        final actorImgTag = actor["ImageTags"]?["Primary"];

                        final actorUrl = actorId != null
                            ? ImageService.person(
                          widget.serverUrl,
                          actorId.toString(),
                          widget.token,
                          tag: actorImgTag,
                        )
                            : null;

                        return Container(
                          width: 100,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: actorUrl != null
                                    ? Image.network(
                                  actorUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Image.asset(
                                        "assets/actor_placeholder.png",
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                )
                                    : Image.asset(
                                  "assets/actor_placeholder.png",
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                actor["Name"] ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                const TextStyle(color: Colors.white),
                              ),
                              Text(
                                actor["Role"] ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // BOTÓN ATRÁS ---------------------------------------------------------
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
