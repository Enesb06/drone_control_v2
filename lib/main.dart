import 'package:flutter/material.dart';
import 'package:drone_control_v2/screens/home_page.dart';
import 'package:drone_control_v2/screens/dashboard_page.dart';
import 'package:drone_control_v2/screens/settings_page.dart'; // Yeni sayfamızı import ediyoruz
import 'package:drone_control_v2/services/settings_service.dart'; // Servisi import ediyoruz

// main fonksiyonunu async yapıyoruz
void main() async {
  // Flutter binding'lerinin hazır olduğundan emin ol
  WidgetsFlutterBinding.ensureInitialized();

  // Uygulama başlamadan önce ayarları yükle
  await SettingsService.instance.initialize();

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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/dashboard': (context) => const DroneDashboardPage(),
        '/settings': (context) => const SettingsPage(), // Yeni rotayı ekliyoruz
      },
    );
  }
}
