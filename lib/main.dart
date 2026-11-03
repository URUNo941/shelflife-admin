import 'package:flutter/material.dart';
import 'views/master_catalog_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShelfLife',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0D7A53),
        useMaterial3: true,
      ),
      home: const MasterCatalogView(),
    );
  }
}