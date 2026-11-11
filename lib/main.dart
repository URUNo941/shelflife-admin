import 'package:flutter/material.dart';
import 'package:myapp/views/user/user_main_view.dart';


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
      home: const UserMainView(), // 2. เปลี่ยนตรงนี้เป็น AdminMainView() หรือ UserMainView()
    );
  }
}