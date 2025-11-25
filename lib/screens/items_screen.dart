import 'package:flutter/material.dart';
import '../services/items_service.dart';
import '../services/image_service.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

class ItemsScreen extends StatefulWidget {
  final String serverUrl;
  final String token;
  final String userId;
  final String parentId;
  final String title;

  /// “movies”, “tvshows”, “boxsets” o ""
  final String collectionType;

  const ItemsScreen({
    super.key,
    required this.serverUrl,
    required this.token,
    required this.userId,
    required this.parentId,
    required this.title,
    required this.collectionType,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  bool loading = true;
  List items = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    String includeType = "";

    if (widget.collectionType == "movies") includeType = "Movie";
    if (widget.collectionType == "tvshows") includeType = "Series";
    if (widget.collectionType == "boxsets") includeType = "BoxSet";

    final result = await ItemsService.getItems(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
      parentId: widget.parentId,
      includeItemTypes: includeType,
    );

    setState(() {
      items = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;

    if (width > 600) crossAxisCount = 3;
    if (width > 900) crossAxisCount = 5;
    if (width > 1300) crossAxisCount = 7;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index] as Map;

          final String? imgTag = item["ImageTags"]?["Primary"];
          final String itemId = item["Id"];
          final String type = item["Type"];

          // URL usando ImageService
          final posterUrl = imgTag != null
              ? ImageService.poster(
            widget.serverUrl,
            itemId,
            tag: imgTag,
          )
              : null;

          return GestureDetector(
            onTap: () {
              if (type == "Movie" || type == "Video") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(
                      serverUrl: widget.serverUrl,
                      token: widget.token,
                      userId: widget.userId,
                      itemId: itemId,
                    ),
                  ),
                );
              } else if (type == "Series") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesDetailScreen(
                      serverUrl: widget.serverUrl,
                      token: widget.token,
                      userId: widget.userId,
                      itemId: itemId,
                    ),
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // POSTER + Fallback con errorBuilder
                  posterUrl != null
                      ? Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/placeholder.png',
                        fit: BoxFit.cover,
                      );
                    },
                  )
                      : Image.asset(
                    'assets/placeholder.png',
                    fit: BoxFit.cover,
                  ),

                  // Overlay inferior con título
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      color: Colors.black.withOpacity(0.60),
                      child: Text(
                        item["Name"] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
