import 'package:flutter/material.dart';
import 'package:drone_control_v2/screens/home_page.dart'; // Yeni ana sayfamızı import ediyoruz
import 'package:drone_control_v2/screens/dashboard_page.dart'; // Grafik sayfamızı import ediyoruz

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Titreşim Monitörü',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF161625),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,

      // --- NAVİGASYON AYARLARI ---
      // Uygulama ilk açıldığında hangi sayfanın gösterileceği
      initialRoute: '/',
      // Hangi rotanın hangi sayfayı oluşturacağını tanımlıyoruz
      routes: {
        '/': (context) => const HomePage(),
        '/dashboard': (context) => const DroneDashboardPage(),
      },
    );
  }
}
