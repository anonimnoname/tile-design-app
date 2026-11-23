import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final url = TextEditingController(text: widget.settings.serverUrl);
  late final admin = TextEditingController(text: widget.settings.adminPath);

  @override
  void dispose() {
    url.dispose();
    admin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.settings.serverUrl = AppSettings.normalizeUrl(url.text);
    widget.settings.adminPath = admin.text.trim().isEmpty ? 'admin' : admin.text.trim();
    await widget.settings.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text('Адрес сайта магазина', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Когда сайт заработает, впишите его адрес — программа будет брать каталог и цены с сайта '
              '(и помнить их, если пропадёт интернет). Пока поле пустое, каталог ведётся прямо в программе.',
              style: TextStyle(color: Color(0xFFB5AC9F)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'https://ваш-сайт.uz'),
            ),
            const SizedBox(height: 24),
            const Text('Адрес админки на сайте', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('То, что задано на сервере в ADMIN_PATH (например, kamron-panel).', style: TextStyle(color: Color(0xFFB5AC9F))),
            const SizedBox(height: 12),
            TextField(controller: admin, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: '/')),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Сохранить'))),
          ]),
        ),
      ),
    );
  }
}
