import 'package:flutter/material.dart';
import '../services/library_service.dart';
import 'items_screen.dart';
import 'SettingsScreen.dart';
import '../services/avatar_notifier.dart';

class HomeScreen extends StatefulWidget {
  final String serverUrl;
  final String token;
  final String userId;

  const HomeScreen({
    super.key,
    required this.serverUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  List libraries = [];

  @override
  void initState() {
    super.initState();
    loadLibraries();
  }

  Future<void> loadLibraries() async {
    final result = await LibraryService.getUserViews(
      serverUrl: widget.serverUrl,
      token: widget.token,
      userId: widget.userId,
    );

    setState(() {
      libraries = result;
      loading = false;
    });
  }

  Widget _buildLibraryTile(Map lib) {
    final name = lib["Name"] ?? "Sin nombre";
    final type = lib["CollectionType"] ?? "";
    final id = lib["Id"] ?? "";

    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.orangeAccent),
      title: Text(name),
      subtitle: Text(type),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemsScreen(
              serverUrl: widget.serverUrl,
              token: widget.token,
              userId: widget.userId,
              parentId: id,
              title: name,
              collectionType: type,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flame Player"),

        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),

            /// 🔥 Avatar que se actualiza automáticamente
            child: ValueListenableBuilder(
              valueListenable: avatarNotifier,
              builder: (_, __, ___) {
                final profileImageUrl =
                    "${widget.serverUrl}/Users/${widget.userId}/Images/Primary";

                return GestureDetector(
                  onTap: () {},
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    child: ClipOval(
                      child: Image.network(
                        profileImageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            "assets/default_user.png",
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: libraries.length,
        itemBuilder: (context, index) {
          final lib = libraries[index] as Map;
          return _buildLibraryTile(lib);
        },
      ),
    );
  }
}
