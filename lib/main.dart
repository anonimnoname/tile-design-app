import 'package:flutter/material.dart';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/admin_screen.dart';
import 'screens/design_screen.dart';
import 'database/db_helper.dart';

// Расширение для красивого форматирования чисел (1234567 -> 1 234 567)
extension NumberFormatter on double {
  String toSpaceSeparated() {
    return toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // МАГИЯ ДЛЯ WINDOWS: включаем поддержку SQLite
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Инициализируем локальную базу данных SQLite перед запуском
  await DesignDbHelper.instance.database;

  // Запускаем приложение
  runApp(const TileDesignApp());
}

class TileDesignApp extends StatelessWidget {
  const TileDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3D Kamron: Дизайн и Склад',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // ВОТ ОНО: Теперь при запуске открывается главное меню!
      home: const MainMenuScreen(),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 3D Kamron: Магазин кафеля'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Кнопка ДИЗАЙН
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.design_services, size: 30),
                  label: const Text('Дизайн и расчет',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DesignScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              // Кнопка АДМИН ПАНЕЛЬ
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.admin_panel_settings, size: 30),
                  label: const Text('Админ панель (Каталог)',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
