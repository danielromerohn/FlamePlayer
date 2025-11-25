import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/emby_service.dart';
import '../services/image_service.dart';
import 'change_avatar_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? serverUrl;
  String? token;
  String? userId;
  String? userName;

  bool loading = true;
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final s = await StorageService.getServerUrl();
    final t = await StorageService.getToken();
    final u = await StorageService.getUserId();

    print("### DEBUG ###");
    print("SERVER: $s");
    print("TOKEN: $t");
    print("USER ID: $u");

    if (s != null && t != null && u != null) {
      final userInfo = await EmbyService.getUserInfo(
        serverUrl: s,
        token: t,
        userId: u,
      );

      setState(() {
        serverUrl = s;
        token = t;
        userId = u;
        userName = userInfo?["Name"] ?? "Usuario";
        avatarUrl = ImageService.userAvatar(s, u);
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await StorageService.clearAll();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openChangeAvatar() async {
    if (serverUrl == null || token == null || userId == null) return;

    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeAvatarScreen(
          serverUrl: serverUrl!,
          token: token!,
          userId: userId!,
        ),
      ),
    );

    // Si el usuario seleccionó un nuevo avatar, refrescamos
    if (changed == true) {
      setState(() {
        avatarUrl = ImageService.userAvatar(serverUrl!, userId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          // FOTO DE PERFIL
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : const AssetImage("assets/default_user.png")
              as ImageProvider,
              onBackgroundImageError: (_, __) {},
            ),
          ),

          const SizedBox(height: 16),

          // Nombre del usuario
          Center(
            child: Text(
              userName ?? "Usuario",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 30),

          // CAMBIAR FOTO
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text("Cambiar foto"),
            onTap: _openChangeAvatar,
          ),

          // CAMBIAR PIN (Aún sin implementar)
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Cambiar PIN"),
            onTap: () {},
          ),

          // CERRAR SESIÓN
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Cerrar sesión",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
