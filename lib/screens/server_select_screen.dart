import 'package:flutter/material.dart';
import '../services/server_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class ServerSelectScreen extends StatefulWidget {
  const ServerSelectScreen({super.key});

  @override
  State<ServerSelectScreen> createState() => _ServerSelectScreenState();
}

class _ServerSelectScreenState extends State<ServerSelectScreen> {
  final TextEditingController serverController = TextEditingController();
  final ServerService _service = ServerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conectar al Servidor")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                labelText: "URL del servidor",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String url = serverController.text.trim();

                // 1) Agregar https:// si falta
                if (!url.startsWith("http://") && !url.startsWith("https://")) {
                  url = "https://$url";
                }

                // 2) Quitar / final
                if (url.endsWith("/")) {
                  url = url.substring(0, url.length - 1);
                }

                // 3) Probar servidor
                final isValid = await _service.testServer(url);

                if (!isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Servidor no válido o no responde")),
                  );
                  return;
                }

                // 4) Guardar la URL normalizada
                await StorageService.saveServerUrl(url);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen(serverUrl: url)),
                );
              },
              child: const Text("Conectar"),
            )

          ],
        ),
      ),
    );
  }
}
