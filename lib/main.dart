import 'package:flutter/material.dart';
import 'screens/server_select_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlamePlayerApp());
}

class FlamePlayerApp extends StatelessWidget {
  const FlamePlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flame Player",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
      ),
      home: const ServerSelectScreen(),
    );
  }
}
