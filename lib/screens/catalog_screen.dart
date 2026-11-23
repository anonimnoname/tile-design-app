import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_settings.dart';
import '../services/browser_launcher.dart';
import '../services/catalog_store.dart';

String _money(num v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

/// Каталог плитки. Без сайта — полноценное редактирование (как старая «Админ панель»).
/// С сайтом — только просмотр, товары меняются в админке сайта.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.settings, required this.store});
  final AppSettings settings;
  final CatalogStore store;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Tile> siteTiles = [];
  String query = '';

  bool get remote => widget.settings.usesServer;

  @override
  void initState() {
    super.initState();
    if (remote) _loadSite();
  }

  Future<void> _loadSite() async {
    try {
      final j = jsonDecode(await widget.store.readCache() ?? '{}') as Map<String, dynamic>;
      final list = (j['products'] as List? ?? []).map((e) => Tile(Map<String, dynamic>.from(e as Map))).toList();
      setState(() => siteTiles = list);
    } catch (_) {}
  }

  List<Tile> get _visible {
    final src = remote ? siteTiles : widget.store.tiles;
    final q = query.trim().toLowerCase().replaceAll('×', 'x');
    if (q.isEmpty) return src;
    return src.where((t) => '${t.name} ${t.w}x${t.h}'.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      appBar: AppBar(title: Text(remote ? 'Каталог с сайта' : 'Каталог плитки')),
      floatingActionButton: remote
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Добавить плитку')),
      body: Column(children: [
        if (remote)
          MaterialBanner(
            content: const Text('Каталог берётся с сайта. Добавлять товары, менять цены и фото — в админке сайта.'),
            actions: [TextButton(onPressed: () => BrowserLauncher.openDefault(widget.settings.adminUrl), child: const Text('Открыть админку'))],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск: название или размер (75x150)', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Пока пусто. Нажмите «Добавить плитку».'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(list[i]),
                ),
        ),
      ]),
    );
  }

  Widget _row(Tile t) {
    final img = remote ? null : t.imageFile(widget.settings);
    return Material(
      color: kDark2,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 54, height: 54,
            child: img != null && File(img).existsSync()
                ? Image.file(File(img), fit: BoxFit.cover)
                : Container(color: const Color(0xFF3A3631), child: const Icon(Icons.texture, color: kGold)),
          ),
        ),
        title: Text('${t.name}${t.isNew ? '  · новинка' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${t.w}×${t.h} см · ${kStyles[t.style] ?? ''} · ${_money(t.price)} сум/м² · ${t.box} м²/кор.'),
        trailing: remote
            ? (t.inStock ? null : const Text('под заказ'))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('В наличии'),
                Switch(
                  value: t.inStock,
                  onChanged: (v) async {
                    t.data['inStock'] = v;
                    await widget.store.save();
                    setState(() {});
                  },
                ),
                IconButton(tooltip: 'Изменить', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(t)),
                IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(t)),
              ]),
      ),
    );
  }

  Future<void> _delete(Tile t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Удалить «${t.name}»?'),
        content: const Text('Если плитка просто закончилась, лучше выключите «В наличии».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.remove(t);
      setState(() {});
    }
  }

  Future<void> _edit(Tile? existing) async {
    final d = Map<String, dynamic>.from(existing?.data ??
        {
          'id': CatalogStore.newId(), 'w': 60, 'h': 120, 'box': 1.44, 'style': 'marble',
          'use': ['wall', 'floor'], 'inStock': true, 'isNew': true, 'active': true, 'finish': '', 'country': '',
        });
    final name = TextEditingController(text: d['name'] as String? ?? '');
    final price = TextEditingController(text: d['price'] == null ? '' : (d['price'] as num).toStringAsFixed(0));
    final box = TextEditingController(text: '${d['box'] ?? ''}');
    final finish = TextEditingController(text: d['finish'] as String? ?? '');
    var size = '${d['w']}x${d['h']}';
    if (!kSizes.any((s) => '${s[0]}x${s[1]}' == size)) size = '60x120';
    var style = kStyles.containsKey(d['style']) ? d['style'] as String : 'solid';
    final use = Set<String>.from((d['use'] as List? ?? const []).cast<String>());
    var inStock = d['inStock'] != false, isNew = d['isNew'] == true;
    String? photo = d['image'] as String?;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        final photoFile = photo != null ? File(Tile({'image': photo}).imageFile(widget.settings)!) : null;
        return AlertDialog(
          title: Text(existing == null ? 'Новая плитка' : 'Изменить плитку'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 110, height: 110,
                      child: photoFile != null && photoFile.existsSync()
                          ? Image.file(photoFile, fit: BoxFit.cover)
                          : Container(color: const Color(0xFF3A3631), child: const Icon(Icons.photo_outlined, size: 40, color: kGold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(photo == null ? 'Выбрать фото плитки' : 'Заменить фото'),
                        onPressed: () async {
                          final r = await FilePicker.platform.pickFiles(type: FileType.image);
                          final path = r?.files.single.path;
                          if (path != null) {
                            final url = await widget.store.importPhoto(path);
                            setD(() => photo = url);
                          }
                        },
                      ),
                      if (photo != null) TextButton(onPressed: () => setD(() => photo = null), child: const Text('Убрать фото')),
                      const Text('Одна плитка, снятая ровно сверху, без бликов.', style: TextStyle(fontSize: 12, color: Color(0xFFB5AC9F))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: size,
                      decoration: const InputDecoration(labelText: 'Размер'),
                      items: [for (final s in kSizes) DropdownMenuItem(value: '${s[0]}x${s[1]}', child: Text('${s[0]}×${s[1]} см'))],
                      onChanged: (v) => setD(() => size = v ?? size),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: style,
                      decoration: const InputDecoration(labelText: 'Стиль'),
                      items: [for (final e in kStyles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => setD(() => style = v ?? style),
                    ),
                  ),
                ]),
                Row(children: [
                  Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена за 1 м², сум'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: box, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'м² в коробке'))),
                ]),
                TextField(controller: finish, decoration: const InputDecoration(labelText: 'Поверхность (полированный, матовый…)')),
                const SizedBox(height: 12),
                const Text('Где можно класть'),
                Wrap(spacing: 8, children: [
                  for (final e in kUses.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: use.contains(e.key),
                      onSelected: (v) => setD(() => v ? use.add(e.key) : use.remove(e.key)),
                    ),
                ]),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('В наличии'), value: inStock, onChanged: (v) => setD(() => inStock = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Новинка'), value: isNew, onChanged: (v) => setD(() => isNew = v)),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final pr = double.tryParse(price.text.replaceAll(' ', '').replaceAll(',', '.'));
                final bx = double.tryParse(box.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty) return setD(() => error = 'Укажите название');
                if (pr == null || pr < 0) return setD(() => error = 'Укажите цену');
                if (bx == null || bx <= 0) return setD(() => error = 'Укажите, сколько м² в коробке');
                if (use.isEmpty) return setD(() => error = 'Отметьте, где можно класть');
                final wh = size.split('x').map(int.parse).toList();
                d
                  ..['name'] = name.text.trim()
                  ..['w'] = wh[0]
                  ..['h'] = wh[1]
                  ..['price'] = pr
                  ..['box'] = bx
                  ..['finish'] = finish.text.trim()
                  ..['style'] = style
                  ..['use'] = use.toList()
                  ..['cats'] = Tile.catsFor(use.toList())
                  ..['inStock'] = inStock
                  ..['isNew'] = isNew
                  ..['active'] = true
                  ..['material'] = Tile.materialFor(style);
                if (photo != null) {
                  d['image'] = photo;
                } else {
                  d.remove('image');
                }
                Navigator.pop(c, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      }),
    );
    if (saved == true) {
      await widget.store.upsert(Tile(d));
      setState(() {});
    }
  }
}
