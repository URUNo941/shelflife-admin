import 'package:flutter/material.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/views/user/login_view.dart';

void main() {
  // แอปจริงคุยกับ backend (Node.js + MySQL) ผ่าน API
  // เปลี่ยนที่อยู่ได้ด้วย --dart-define=API_BASE_URL=http://<ip>:3000/api
  ApiClient.instance.enable();
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
      // เริ่มที่หน้า Login เสมอ แล้วพาไปหน้า User หรือ Admin ตาม role
      home: const LoginView(),
    );
  }
}
