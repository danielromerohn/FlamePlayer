// lib/screens/series_detail_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/emby_service.dart';
import '../services/image_service.dart'; // ← IMPORTANTE
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String token;
  final String userId;
  final String itemId;

  const SeriesDetailScreen({
    super.key,
    required this.serverUrl,
    required this.token,
    required this.userId,
    required this.itemId,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? itemInfo;
  List<dynamic> children = [];
  List<dynamic> seasons = [];
  TabController? _tabController;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);

    final info = await EmbyService.getItemInfo(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: widget.itemId,
    );

    final kids = await EmbyService.getChildren(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      parentId: widget.itemId,
    );

    final foundSeasons = <dynamic>[];
    final episodesDirect = <dynamic>[];

    if (kids != null) {
      for (final k in kids) {
        if (k['Type'] == 'Season') {
          foundSeasons.add(k);
        } else if (k['Type'] == 'Episode') {
          episodesDirect.add(k);
        }
      }
    }

    setState(() {
      itemInfo = info;
      children = episodesDirect;
      seasons = foundSeasons;

      if (seasons.isNotEmpty) {
        _tabController = TabController(length: seasons.length, vsync: this);
      }

      loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // BACKDROP usando ImageService
  // ---------------------------------------------------------------------------
  Widget _buildBackdrop(double height) {
    final id = itemInfo?['Id']?.toString();
    final tag = (itemInfo?['BackdropImageTags'] is List &&
        itemInfo!['BackdropImageTags'].isNotEmpty)
        ? itemInfo!['BackdropImageTags'][0].toString()
        : null;

    if (id == null) {
      return Container(height: height, color: Colors.black87);
    }

    final url = ImageService.backdrop(
      widget.serverUrl,
      id,
      tag: tag,
      apiKey: widget.token,
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(url, fit: BoxFit.cover),
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POSTER usando ImageService
  // ---------------------------------------------------------------------------
  Widget _poster(double w, double h) {
    final id = itemInfo?['Id']?.toString();
    final imgTag = itemInfo?['ImageTags']?['Primary'];

    if (id == null || imgTag == null) {
      return Container(width: w, height: h, color: Colors.grey[800]);
    }

    final url = ImageService.poster(
      widget.serverUrl,
      id,
      tag: imgTag,
      apiKey: widget.token,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PLAY
  // ---------------------------------------------------------------------------
  Future<void> _onPlayPressed(Map ep) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final playable = await EmbyService.getPlayablePathRecursive(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: ep['Id'].toString(),
    );

    Navigator.pop(context);

    if (playable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró archivo reproducible")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: playable,
          title: ep['Name'] ?? itemInfo?['Name'] ?? "Reproduciendo",
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EPISODE TILE con ImageService + fallback
  // ---------------------------------------------------------------------------
  Widget _episodeTile(Map ep) {
    final id = ep['Id']?.toString() ?? "";
    final name = ep['Name'] ?? "Episodio";
    final tag = ep['ImageTags']?['Primary'];

    final thumb = (id.isNotEmpty && tag != null)
        ? ImageService.poster(
      widget.serverUrl,
      id,
      tag: tag,
      apiKey: widget.token,
      maxWidth: 400,
    )
        : "asset://fallback";

    final hasFallback = thumb.startsWith("asset://");

    return ListTile(
      leading: hasFallback
          ? Image.asset(
        "assets/actor_placeholder.png",
        width: 90,
        fit: BoxFit.cover,
      )
          : Image.network(
        thumb,
        width: 90,
        fit: BoxFit.cover,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        "Episodio ${ep['IndexNumber'] ?? ''}",
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: ElevatedButton(
        child: const Text("Reproducir"),
        onPressed: () => _onPlayPressed(ep),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(
              serverUrl: widget.serverUrl,
              token: widget.token,
              userId: widget.userId,
              itemId: ep['Id'].toString(),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SEASONS TABS
  // ---------------------------------------------------------------------------
  Widget _seasonsTabs() {
    if (seasons.isEmpty) return const SizedBox();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final s in seasons) Tab(text: s['Name'] ?? 'Temporada'),
          ],
        ),
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final s in seasons)
                FutureBuilder<List<dynamic>?>(
                  future: EmbyService.getChildren(
                    serverUrl: widget.serverUrl,
                    token: widget.token,
                    userId: widget.userId,
                    parentId: s['Id'].toString(),
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snap.data ?? [];

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, idx) =>
                          _episodeTile(list[idx] as Map),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildBackdrop(height),

            // POSTER + INFO
            Transform.translate(
              offset: const Offset(0, -60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _poster(140, 210),
                    const SizedBox(width: 18),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemInfo?['Name'] ?? 'Sin título',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (itemInfo?['Overview'] != null)
                            Text(
                              itemInfo!['Overview'],
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Continuar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () {
                                  if (children.isNotEmpty) {
                                    _onPlayPressed(children[0] as Map);
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.list),
                                label: const Text('Temporadas'),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // SEASONS OR EPISODES
            if (seasons.isNotEmpty) _seasonsTabs(),

            if (seasons.isEmpty && children.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Episodios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white12),
                itemBuilder: (context, idx) =>
                    _episodeTile(children[idx] as Map),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
