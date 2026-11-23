import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart' show kDark2, kGold, kLight;
import '../services/app_settings.dart';
import '../services/autostart.dart';
import '../services/browser_launcher.dart';
import 'settings_screen.dart';

const _autostartName = '3D Kamron Zakazy';

/// «3D Kamron Заказы»: окно с заказами сайта (админка) в отдельном окне Edge.
/// Новые заказы приходят уведомлением в углу экрана Windows (push), даже когда окно закрыто.
class OrdersHomeScreen extends StatefulWidget {
  const OrdersHomeScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<OrdersHomeScreen> createState() => _OrdersHomeScreenState();
}

class _OrdersHomeScreenState extends State<OrdersHomeScreen> {
  String status = '';
  bool autostart = false;

  AppSettings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    autostart = Autostart.isOn(_autostartName);
    _check().then((ok) {
      if (ok && s.autoOpen) _openOrders();
    });
  }

  Future<bool> _check() async {
    if (!s.usesServer) {
      setState(() => status = 'Впишите адрес сайта в настройках (шестерёнка справа вверху).');
      return false;
    }
    setState(() => status = 'Проверяем связь с сайтом…');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final rq = await client.getUrl(Uri.parse('${s.serverUrl}/api/catalog'));
      final rs = await rq.close().timeout(const Duration(seconds: 10));
      await rs.drain<void>();
      final ok = rs.statusCode == 200;
      if (mounted) setState(() => status = ok ? 'Сайт на связи: ${s.serverUrl}' : 'Сайт ответил ошибкой ${rs.statusCode}');
      return ok;
    } catch (_) {
      if (mounted) setState(() => status = 'Нет связи с сайтом. Проверьте интернет и адрес сайта.');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _openOrders() => BrowserLauncher.openApp(s.adminUrl, profileDir: s.browserProfileDir.path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(32), children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: kGold, size: 34),
                const SizedBox(width: 12),
                const Text('3D Kamron · Заказы', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: kLight)),
                const Spacer(),
                IconButton(
                  tooltip: 'Настройки',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: s)));
                    await _check();
                  },
                ),
              ]),
              const SizedBox(height: 28),
              Material(
                color: kLight,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: s.usesServer ? _openOrders : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                    child: Row(children: [
                      Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF151412)),
                      SizedBox(width: 18),
                      Expanded(
                        child: Text('Открыть заказы',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF151412))),
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFF151412)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(status, style: const TextStyle(color: Color(0xFFB5AC9F))),
              const SizedBox(height: 22),
              SwitchListTile(
                value: s.autoOpen,
                title: const Text('Открывать заказы сразу при запуске программы'),
                onChanged: (v) async {
                  s.autoOpen = v;
                  await s.save();
                  setState(() {});
                },
              ),
              if (Autostart.supported(_autostartName))
                SwitchListTile(
                  value: autostart,
                  title: const Text('Запускать вместе с Windows'),
                  subtitle: const Text('Ноутбук включили — заказы уже открыты'),
                  onChanged: (v) async {
                    await Autostart.set(_autostartName, v);
                    setState(() => autostart = Autostart.isOn(_autostartName));
                  },
                ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: kDark2, borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  'Один раз на этом ноутбуке:\n'
                  '1. Нажмите «Открыть заказы» и войдите паролем админки.\n'
                  '2. В окне заказов нажмите «🔔 Включить уведомления» и разрешите.\n\n'
                  'Дальше каждый новый заказ всплывает в углу экрана Windows — даже если окно заказов закрыто. '
                  'Щелчок по уведомлению открывает заказ. В заказе — кнопки «Подтвердить в WhatsApp / Telegram» '
                  'с готовым сообщением и реквизитами.',
                  style: TextStyle(color: Color(0xFFB5AC9F), height: 1.5),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
