import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String serverUrl;
  const LoginScreen({super.key, required this.serverUrl});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  void doLogin() async {
    setState(() {
      loading = true;
      error = null;
    });

    final result = await AuthService.login(
      serverUrl: widget.serverUrl,
      username: userCtrl.text.trim(),
      password: passCtrl.text.trim(),
    );

    setState(() => loading = false);

    if (result == null) {
      setState(() => error = "Usuario o contraseña incorrectos");
      return;
    }

    final token = result["AccessToken"];
    final userId = result["User"]["Id"];

    // Guardar datos localmente
    await StorageService.saveServerUrl(widget.serverUrl);
    await StorageService.saveToken(token);
    await StorageService.saveUserId(userId);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          serverUrl: widget.serverUrl,
          token: token,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Iniciar sesión")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: "Usuario",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contraseña",
              ),
            ),
            const SizedBox(height: 20),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: doLogin,
              child: const Text("Entrar"),
            ),
          ],
        ),
      ),
    );
  }
}
