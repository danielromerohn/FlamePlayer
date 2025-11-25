// lib/screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/emby_service.dart';
import 'player_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final String serverUrl;
  final String token;
  final String userId;
  final String itemId;

  const ItemDetailScreen({
    super.key,
    required this.serverUrl,
    required this.token,
    required this.userId,
    required this.itemId,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? itemInfo;
  bool loading = true;
  List<dynamic> children = [];
  TabController? _tabController;
  bool isSeriesWithSeasons = false;
  List<dynamic> seasons = [];

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() { loading = true; });

    final info = await EmbyService.getItemInfo(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,     // <-- agregado
      itemId: widget.itemId,
    );

    Map<String, dynamic>? loadedInfo = info;

    // if item is a folder (series/season/movie folder) we also fetch children for listing
    final childrenRes = await EmbyService.getChildren(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      parentId: widget.itemId,
    );

    // If children exist, analyze if they are seasons (Type == Season) or episodes
    bool hasSeason = false;
    List<dynamic> foundSeasons = [];
    if (childrenRes != null && childrenRes.isNotEmpty) {
      for (final c in childrenRes) {
        if (c['Type'] == 'Season') {
          hasSeason = true;
          foundSeasons.add(c);
        }
      }
    }

    // if there are seasons, load each season's children (episodes)
    if (hasSeason) {
      isSeriesWithSeasons = true;
      seasons = foundSeasons;
      // create tab controller
      _tabController = TabController(length: seasons.length, vsync: this);
      // optionally load children per season lazily later in UI
    } else {
      // not seasons: keep children as list of episodes/movies
      children = childrenRes ?? [];
    }

    setState(() {
      itemInfo = loadedInfo;
      loading = false;
    });
  }

  Widget _posterWidget() {
    final id = itemInfo?['Id']?.toString();
    final imageTag = itemInfo?['ImageTags']?['Primary'];
    if (id == null || imageTag == null) {
      return Container(
        width: 140,
        height: 210,
        color: Colors.grey[800],
        child: const Icon(Icons.movie, size: 60, color: Colors.white24),
      );
    }
    final url = EmbyService.imageUrl(
      serverUrl: widget.serverUrl,
      itemId: id,
      imageTag: imageTag,
      maxWidth: 800,
      apiKeyParam: widget.token,
    );
    return Image.network(url, width: 140, height: 210, fit: BoxFit.cover);
  }

  Widget _buildMetadata() {
    final title = itemInfo?['Name'] ?? 'Sin título';
    final overview = itemInfo?['Overview'] ?? '';
    final year = itemInfo?['ProductionYear']?.toString() ?? '';
    final runtimeTicks = itemInfo?['RunTimeTicks'];
    String runtimeStr = '';
    if (runtimeTicks != null) {
      final seconds = (runtimeTicks / 10000000).round();
      runtimeStr = '${(seconds/60).round()} min';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [
          if (year.isNotEmpty) Text(year, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 12),
          if (runtimeStr.isNotEmpty) Text(runtimeStr, style: const TextStyle(color: Colors.white70)),
        ]),
        const SizedBox(height: 10),
        Text(overview, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Future<void> _onPlayPressed(Map currentItem) async {
    // currentItem should be the actual item (movie or episode).
    // Call getPlayablePathRecursive to find the real playable URL (descend if folder)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final playable = await EmbyService.getPlayablePathRecursive(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: currentItem['Id'].toString(),
    );

    Navigator.pop(context); // quitar loading

    if (playable == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se encontró un archivo reproducible")));
      return;
    }

    // Abrir player — NO mostramos el enlace al usuario
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: playable,
          title: currentItem['Name'] ?? itemInfo?['Name'] ?? 'Reproduciendo',
        ),
      ),
    );
  }

  Widget _buildChildrenList(List<dynamic> list) {
    if (list.isEmpty) return const SizedBox();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      itemBuilder: (context, idx) {
        final child = list[idx] as Map;
        final title = child['Name'] ?? 'Sin título';
        final subtitle = child['Type'] ?? '';
        return ListTile(
          title: Text(title),
          subtitle: Text(subtitle.toString()),
          trailing: ElevatedButton(
            child: const Text("Reproducir"),
            onPressed: () => _onPlayPressed(child),
          ),
          onTap: () {
            // abrir detalles del hijo (drill-down)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItemDetailScreen(
                  serverUrl: widget.serverUrl,
                  token: widget.token,
                  userId: widget.userId,
                  itemId: child['Id'].toString(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeasonsTabs() {
    if (seasons.isEmpty) return const SizedBox();
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final s in seasons)
              Tab(text: s['Name'] ?? 'Temporada'),
          ],
        ),
        SizedBox(
          height: 300,
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
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final list = snap.data ?? [];
                    return _buildChildrenList(list);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _posterWidget(),
                const SizedBox(width: 16),
                Expanded(child: _buildMetadata()),
              ],
            ),
            const SizedBox(height: 16),

            // Si tiene seasons -> pestañas
            if (isSeriesWithSeasons) _buildSeasonsTabs(),

            // Si no tiene seasons pero tiene children -> listar episodes
            if (!isSeriesWithSeasons && children.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text("Episodios", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildChildrenList(children),
                ],
              ),

            // Si es item individual (movie) mostrar botón reproducir
            if (!(children.isNotEmpty || isSeriesWithSeasons))
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Reproducir"),
                      onPressed: () async {
                        // si itemInfo es folder, no se debe llegar aquí en teoría; pero pasamos itemInfo
                        if (itemInfo == null) return;
                        await _onPlayPressed(itemInfo!);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}