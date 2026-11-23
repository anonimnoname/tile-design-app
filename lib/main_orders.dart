import 'package:flutter/material.dart';

import 'main.dart' show kDark, kDark2, kGold;
import 'screens/orders_home_screen.dart';
import 'services/app_settings.dart';

/// Программа «3D Kamron Заказы» — для ноутбука, на котором принимают заказы с сайта.
/// Сборка: flutter build windows -t lib/main_orders.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load(sub: 'orders');
  runApp(OrdersApp(settings: settings));
}

class OrdersApp extends StatelessWidget {
  const OrdersApp({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3D Kamron · Заказы',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kDark,
        colorScheme: ColorScheme.fromSeed(seedColor: kGold, brightness: Brightness.dark, surface: kDark2),
      ),
      home: OrdersHomeScreen(settings: settings),
    );
  }
}
