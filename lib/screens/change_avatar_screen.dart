import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

class ChangeAvatarScreen extends StatefulWidget {
  final String serverUrl;
  final String token;
  final String userId;

  const ChangeAvatarScreen({
    super.key,
    required this.serverUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  Future<void> uploadLocalAvatar() async {
    try {
      // Cargar asset
      final ByteData data =
      await rootBundle.load("assets/default_user.png");

      final Uint8List bytes = data.buffer.asUint8List();

      print("Bytes del asset: ${bytes.length}");

      // Endpoint real de Emby WebClient
      final url =
          "${widget.serverUrl}/Users/${widget.userId}/Image/Primary";

      final req = http.MultipartRequest("POST", Uri.parse(url))
        ..headers["X-Emby-Token"] = widget.token
        ..files.add(
          http.MultipartFile.fromBytes(
            "file", // nombre correcto según WebClient
            bytes,
            filename: "avatar.png",
          ),
        );

      print("Enviando a: $url");

      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      print("Status: ${resp.statusCode}");
      print("Body: $body");

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar actualizado!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${resp.statusCode}")),
        );
      }
    } catch (e) {
      print("EX: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cambiar avatar")),
      body: Center(
        child: ElevatedButton(
          onPressed: uploadLocalAvatar,
          child: const Text("Probar subir avatar (asset)"),
        ),
      ),
    );
  }
}
