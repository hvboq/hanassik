import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() {
  runApp(const HanassikApp());
}

class HanassikApp extends StatelessWidget {
  const HanassikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하나씩',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6B4F)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F2),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6B4F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
