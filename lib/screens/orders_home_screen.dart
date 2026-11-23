import 'package:flutter/material.dart';

import '../main.dart' show kDark2, kGold, kLight;
import '../services/app_settings.dart';
import '../services/autostart.dart';
import '../services/browser_launcher.dart';
import '../services/order_watcher.dart';
import '../services/site_api.dart';
import 'admin/login_gate.dart';
import 'admin/orders_screen.dart';
import 'admin/products_screen.dart';
import 'admin/shop_settings_screen.dart';
import 'settings_screen.dart';

const _autostartName = '3D Kamron Zakazy';

/// «3D Kamron Заказы» — админка сайта прямо в программе:
/// заказы приходят сами (с уведомлением Windows), товары и настройки — одна база с сайтом.
class OrdersHomeScreen extends StatefulWidget {
  const OrdersHomeScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<OrdersHomeScreen> createState() => _OrdersHomeScreenState();
}

class _OrdersHomeScreenState extends State<OrdersHomeScreen> {
  late final api = SiteApi(widget.settings);
  late final watcher = OrderWatcher(api);
  int tab = 0;
  int gateKey = 0;
  bool started = false;

  @override
  void initState() {
    super.initState();
    watcher.onNotificationTap = () => setState(() => tab = 0);
    watcher.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    watcher.stop();
    super.dispose();
  }

  void _startWatching() {
    if (started) return;
    started = true;
    watcher.start();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kDark2,
        title: const Row(children: [
          Icon(Icons.receipt_long, color: kGold),
          SizedBox(width: 10),
          Text('3D Kamron · Заказы', style: TextStyle(color: kLight, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (watcher.updated != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('обновлено ${_hm(watcher.updated!)}', style: const TextStyle(color: Color(0xFFB5AC9F), fontSize: 13))),
            ),
          IconButton(
            tooltip: 'Открыть админку в браузере',
            icon: const Icon(Icons.open_in_browser),
            onPressed: s.usesServer ? () => BrowserLauncher.openDefault(s.adminUrl) : null,
          ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            onSelected: (v) async {
              if (v == 'settings') {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: s)));
                setState(() { started = false; gateKey++; });
              } else if (v == 'autostart') {
                await Autostart.set(_autostartName, !Autostart.isOn(_autostartName));
                setState(() {});
              } else if (v == 'logout') {
                watcher.stop();
                await api.logout();
                setState(() { started = false; gateKey++; });
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Text('Адрес сайта')),
              if (Autostart.supported(_autostartName))
                CheckedPopupMenuItem(value: 'autostart', checked: Autostart.isOn(_autostartName), child: const Text('Запускать вместе с Windows')),
              const PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
          ),
        ],
      ),
      body: LoginGate(
        key: ValueKey(gateKey),
        api: api,
        child: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _startWatching());
          return Row(children: [
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: Badge(isLabelVisible: watcher.newCount > 0, label: Text('${watcher.newCount}'), child: const Icon(Icons.inbox_outlined)),
                  label: const Text('Заказы'),
                ),
                const NavigationRailDestination(icon: Icon(Icons.grid_view), label: Text('Товары')),
                const NavigationRailDestination(icon: Icon(Icons.storefront_outlined), label: Text('Магазин')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(index: tab, children: [
                OrdersScreen(api: api, watcher: watcher),
                ProductsScreen(api: api),
                ShopSettingsScreen(api: api),
              ]),
            ),
          ]);
        }),
      ),
    );
  }

  static String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
