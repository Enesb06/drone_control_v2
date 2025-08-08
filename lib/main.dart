// main.dart
import 'package:flutter/material.dart';
import 'package:drone_control_v2/screens/home_page.dart';
import 'package:drone_control_v2/screens/dashboard_page.dart';
import 'package:drone_control_v2/screens/settings_page.dart';
import 'package:drone_control_v2/services/settings_service.dart';
import 'package:drone_control_v2/screens/saved_sessions_page.dart';
import 'package:drone_control_v2/screens/product_code_page.dart'; // YENİ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      // Başlangıç rotası artık Ürün Kodu Sayfası
      initialRoute: '/',
      // Rotaları yeniden düzenliyoruz
      routes: {
        '/': (context) => const ProductCodePage(),
        '/home': (context) => const HomePage(),
        '/dashboard': (context) {
          // Dashboard'a geçerken gönderilen argümanı al
          final productCode =
              ModalRoute.of(context)!.settings.arguments as String;
          // Bu argümanı DroneDashboardPage'e constructor ile ver
          return DroneDashboardPage(productCode: productCode);
        },
        '/settings': (context) => const SettingsPage(),
        '/saved_sessions': (context) => const SavedSessionsPage(),
      },
    );
  }
}
