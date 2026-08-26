import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const SiManDistApp());
}

class SiManDistApp extends StatelessWidget {
  const SiManDistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiManDist Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF004D8C),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
