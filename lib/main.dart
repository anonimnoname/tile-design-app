import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/catalog_store.dart';
import 'services/local_server.dart';

/// Цвета как на сайте: тёмный фон, бронзовый акцент.
const kDark = Color(0xFF151412);
const kDark2 = Color(0xFF1F1D1A);
const kGold = Color(0xFFC9A77A);
const kLight = Color(0xFFF3EEE6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final store = CatalogStore(settings);
  await store.load();
  final server = LocalServer(settings, store);
  await server.start();
  runApp(KamronApp(settings: settings, store: store, server: server));
}

class KamronApp extends StatelessWidget {
  const KamronApp({super.key, required this.settings, required this.store, required this.server});
  final AppSettings settings;
  final CatalogStore store;
  final LocalServer server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3D Kamron',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kDark,
        colorScheme: ColorScheme.fromSeed(seedColor: kGold, brightness: Brightness.dark, surface: kDark2),
      ),
      home: HomeScreen(settings: settings, store: store, server: server),
    );
  }
}
