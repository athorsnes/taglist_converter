import 'package:flutter/material.dart';
import 'package:taglist_converter/homepage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taglist converter',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 70, 54)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
