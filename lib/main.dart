// lib/main.dart dosyasının YENİ HALİ

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drone_control_v2/screens/home_page.dart';
import 'package:drone_control_v2/screens/dashboard_page.dart';
import 'package:drone_control_v2/screens/settings_page.dart';
import 'package:drone_control_v2/services/settings_service.dart';
import 'package:drone_control_v2/screens/saved_sessions_page.dart';
import 'package:drone_control_v2/screens/product_code_page.dart';
import 'package:drone_control_v2/screens/wifi_selection_page.dart';
import 'package:drone_control_v2/screens/qr_scanner_page.dart';
import 'package:drone_control_v2/providers/locale_provider.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';
import 'package:drone_control_v2/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.initialize();
  runApp(const MyAppWrapper());
}

class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)!.welcomeMessage,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeProvider.locale,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF161625),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,

      initialRoute: '/splash',
      
      // ---------- DEĞİŞİKLİK BURADA BAŞLIYOR ----------
      // ESKİ routes: { ... } HARİTASINI SİLİP, YERİNE onGenerateRoute EKLEYİN.
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/':
            return MaterialPageRoute(builder: (_) => const HomePage());
          
          // DİKKAT: Bu rota bir String DÖNDÜRECEĞİ için tipini belirtiyoruz.
          case '/product_code':
            return MaterialPageRoute<String>(
              builder: (_) => const ProductCodePage(),
            );
          
          // DİKKAT: Bu rota da bir String DÖNDÜRECEĞİ için tipini belirtiyoruz.
          case '/qr_scanner':
            return MaterialPageRoute<String>(
              builder: (_) => const QRScannerPage(),
            );
            
          case '/wifi_selection':
            return MaterialPageRoute(builder: (_) => const WifiSelectionPage());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsPage());
          case '/saved_sessions':
            return MaterialPageRoute(builder: (_) => const SavedSessionsPage());
            
          case '/dashboard':
            final args = settings.arguments as DashboardArguments;
            return MaterialPageRoute(
              builder: (_) => DroneDashboardPage(args: args),
            );
          
          default:
            // Tanımlanmayan bir rota için bir hata sayfası veya ana sayfa gösterilebilir.
            return MaterialPageRoute(builder: (_) => const HomePage());
        }
      },
      // ---------- DEĞİŞİKLİK BURADA BİTİYOR ----------
    );
  }
}