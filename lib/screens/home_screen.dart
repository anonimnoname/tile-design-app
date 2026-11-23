import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_settings.dart';
import '../services/browser_launcher.dart';
import '../services/catalog_store.dart';
import '../services/local_server.dart';
import '../services/site_api.dart';
import 'admin/login_gate.dart';
import 'admin/products_screen.dart';
import 'catalog_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.store, required this.server});
  final AppSettings settings;
  final CatalogStore store;
  final LocalServer server;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String status = '';
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    if (widget.settings.usesServer) _sync(silent: true);
  }

  Future<void> _updateStatus() async {
    final s = widget.settings, st = widget.store;
    String text;
    if (s.usesServer) {
      final n = await st.cachedCount();
      final t = st.cacheTime;
      text = n > 0
          ? 'Каталог с сайта: $n товаров${t != null ? ', обновлён ${_fmt(t)}' : ''}'
          : 'Каталог с сайта ещё не загружен — нужен интернет';
    } else {
      final n = st.tiles.length;
      text = n > 0 ? 'Свой каталог в программе: $n товаров' : 'Каталог пуст — пока показываются примеры. Добавьте плитку в «Каталог»';
    }
    if (mounted) setState(() => status = text);
  }

  String _fmt(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} в ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _sync({bool silent = false}) async {
    setState(() => syncing = true);
    final ok = await widget.server.fetchSiteCatalog() != null;
    if (!mounted) return;
    setState(() => syncing = false);
    await _updateStatus();
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Каталог обновлён с сайта' : 'Сайт недоступен. Работаем с сохранённым каталогом')));
    }
  }

  Future<void> _open({bool tv = false}) async {
    try {
      await BrowserLauncher.openApp(widget.server.url(tv: tv),
          profileDir: widget.settings.browserProfileDir.path, fullscreen: tv);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть окно: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: [
                Row(children: [
                  Container(width: 12, height: 34, decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Container(width: 12, height: 34, decoration: BoxDecoration(color: kLight, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 14),
                  const Text('3D Kamron · Показ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: kLight)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Настройки',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: s, showAdminPath: false)));
                      await _updateStatus();
                      if (s.usesServer) _sync(silent: true);
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('Крупноформатный керамогранит · 3D-конструктор для клиентов',
                    style: TextStyle(color: Color(0xFFB5AC9F), fontSize: 15)),
                const SizedBox(height: 32),
                _BigButton(
                  icon: Icons.view_in_ar,
                  title: 'Открыть 3D-конструктор',
                  subtitle: 'Форма комнаты, плитка, расчёт коробок, печать расчёта',
                  primary: true,
                  onTap: () => _open(),
                ),
                const SizedBox(height: 14),
                _BigButton(
                  icon: Icons.tv,
                  title: 'Показать на телевизоре',
                  subtitle: 'Окно на весь экран. Кнопка ▶ в конструкторе — презентация с вращением',
                  onTap: () => _open(tv: true),
                ),
                const SizedBox(height: 14),
                _BigButton(
                  icon: Icons.grid_view,
                  title: 'Каталог плитки',
                  subtitle: s.usesServer ? 'Одна база с сайтом: поиск, цены, фото, наличие' : 'Добавить, изменить цену, фото, наличие',
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => s.usesServer
                                // сайт подключён — одна база товаров: правки сразу на сайте и на втором ноутбуке
                                ? Scaffold(
                                    appBar: AppBar(title: const Text('Каталог (база сайта)')),
                                    body: LoginGate(
                                      api: SiteApi(s),
                                      child: ProductsScreen(api: SiteApi(s), onChanged: () => widget.server.fetchSiteCatalog()),
                                    ),
                                  )
                                : CatalogScreen(settings: s, store: widget.store)));
                    await widget.server.fetchSiteCatalog();
                    await _updateStatus();
                  },
                ),
                const SizedBox(height: 26),
                Row(children: [
                  Icon(s.usesServer ? Icons.cloud_done_outlined : Icons.inventory_2_outlined, size: 18, color: kGold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status, style: const TextStyle(color: Color(0xFFB5AC9F)))),
                  if (s.usesServer)
                    TextButton.icon(
                      onPressed: syncing ? null : () => _sync(),
                      icon: syncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: const Text('Обновить с сайта'),
                    ),
                ]),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: kDark2, borderRadius: BorderRadius.circular(16)),
                  child: const Text(
                    'Как показать на ТВ: подключите ноутбук кабелем HDMI, нажмите Win + P и выберите «Повторяющийся» '
                    '(или «Только второй экран»). Затем «Показать на телевизоре». В конструкторе: ▶ — презентация, '
                    '→ — встать внутри комнаты, ← — обзор, Esc — выход.',
                    style: TextStyle(color: Color(0xFFB5AC9F), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.title, required this.subtitle, required this.onTap, this.primary = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? kDark : kLight;
    return Material(
      color: primary ? kLight : kDark2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(children: [
            Icon(icon, size: 34, color: primary ? kDark : kGold),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.7))),
              ]),
            ),
            Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }
}
