import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drone_control_v2/screens/home_page.dart';
import 'package:drone_control_v2/screens/dashboard_page.dart';
import 'package:drone_control_v2/screens/settings_page.dart';
import 'package:drone_control_v2/services/settings_service.dart';
import 'package:drone_control_v2/screens/saved_sessions_page.dart';
import 'package:drone_control_v2/screens/product_code_page.dart';
import 'package:drone_control_v2/screens/wifi_selection_page.dart';
import 'package:drone_control_v2/providers/locale_provider.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const ProductCodePage(),
        '/home': (context) => const HomePage(),
        '/wifi_selection': (context) => const WifiSelectionPage(),
        '/dashboard': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as DashboardArguments;
          return DroneDashboardPage(args: args);
        },
        '/settings': (context) => const SettingsPage(),
        '/saved_sessions': (context) => const SavedSessionsPage(),
      },
    );
  }
}