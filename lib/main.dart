import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:taglist_converter/homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  runApp(MyApp(packageInfo: packageInfo));
}

class MyApp extends StatelessWidget {
  final PackageInfo packageInfo;
  const MyApp({super.key, required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taglist converter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 0, 70, 54)),
        useMaterial3: true,
      ),
      home: HomePage(
        packageInfo: packageInfo,
      ),
    );
  }
}
