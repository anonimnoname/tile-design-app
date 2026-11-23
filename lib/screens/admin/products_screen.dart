import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../main.dart' show kDark2, kGold;
import '../../services/catalog_store.dart' show kSizes, kStyles, kUses, Tile;
import '../../services/order_watcher.dart' show money;
import '../../services/site_api.dart';

/// Товары сайта: одна база для сайта и обоих ноутбуков. Добавили здесь — товар сразу
/// на сайте, в программе «Показ» и в 3D-конструкторе.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.api, this.onChanged});
  final SiteApi api;
  final VoidCallback? onChanged;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> items = [];
  String query = '', size = 'all', style = 'all';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      items = await widget.api.products();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  List<Map<String, dynamic>> get _visible {
    final q = query.trim().toLowerCase().replaceAll('×', 'x');
    return items.where((p) {
      final w = p['w'] as num, h = p['h'] as num;
      final sk = '${w < h ? w : h}x${w < h ? h : w}';
      if (size != 'all' && sk != size) return false;
      if (style != 'all' && p['style'] != style) return false;
      if (q.isEmpty) return true;
      return '${p['name']} ${p['collection'] ?? ''} ${p['country'] ?? ''} $sk ${w}x$h'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _patch(Map<String, dynamic> p, Map<String, dynamic> body) async {
    try {
      final u = await widget.api.patchProduct(p['id'] as String, body);
      p.addAll(u);
      setState(() {});
      widget.onChanged?.call();
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Добавить товар')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск: название, коллекция, страна, размер (75x150)', border: OutlineInputBorder(), isDense: true),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: size,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Все размеры')),
                for (final s in kSizes) DropdownMenuItem(value: '${s[0]}x${s[1]}', child: Text('${s[0]}×${s[1]}')),
              ],
              onChanged: (v) => setState(() => size = v ?? 'all'),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: style,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Все стили')),
                for (final e in kStyles.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => style = v ?? 'all'),
            ),
            IconButton(tooltip: 'Обновить', onPressed: _load, icon: const Icon(Icons.refresh)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(alignment: Alignment.centerLeft, child: Text('${list.length} из ${items.length}', style: const TextStyle(color: Color(0xFFB5AC9F)))),
        ),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(list[i]),
                ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final img = p['image'] as String?;
    final active = p['active'] != false;
    return Opacity(
      opacity: active ? 1 : 0.55,
      child: Material(
        color: kDark2,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56, height: 56,
                child: img != null
                    ? Image.network('${widget.api.settings.serverUrl}$img', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                    : Container(color: const Color(0xFF3A3631), child: const Icon(Icons.texture, color: kGold)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['name']}${p['isNew'] == true ? '  · новинка' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${p['w']}×${p['h']} см · ${kStyles[p['style']] ?? ''} · ${p['box']} м²/кор.', style: const TextStyle(color: Color(0xFFB5AC9F), fontSize: 13)),
              ]),
            ),
            SizedBox(
              width: 140,
              child: TextFormField(
                key: ValueKey('price-${p['id']}-${p['price']}'),
                initialValue: (p['price'] as num).toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Цена/м², сум', isDense: true, border: OutlineInputBorder()),
                onFieldSubmitted: (v) {
                  final n = num.tryParse(v.replaceAll(' ', ''));
                  if (n != null) _patch(p, {'price': n}).then((_) => _snack('Цена: ${money(n)} сум'));
                },
              ),
            ),
            const SizedBox(width: 10),
            _flag('В наличии', p['inStock'] == true, (v) => _patch(p, {'inStock': v})),
            _flag('На сайте', active, (v) => _patch(p, {'active': v})),
            IconButton(tooltip: 'Изменить', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(p)),
            IconButton(tooltip: 'Копия', icon: const Icon(Icons.copy_outlined), onPressed: () => _edit(Map.of(p)..remove('id')..['name'] = '${p['name']} (копия)')),
            IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(p)),
          ]),
        ),
      ),
    );
  }

  Widget _flag(String label, bool v, ValueChanged<bool> on) => Column(mainAxisSize: MainAxisSize.min, children: [
        Switch(value: v, onChanged: on),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFB5AC9F))),
      ]);

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Удалить «${p['name']}» навсегда?'),
        content: const Text('Если плитка закончилась — лучше выключите «В наличии» или «На сайте».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteProduct(p['id'] as String);
      setState(() => items.remove(p));
      widget.onChanged?.call();
    } catch (e) {
      _snack('$e');
    }
  }

  /// Простая «имитация» по стилю, если фото нет (тот же формат, что в веб-админке).
  static Map<String, dynamic> _look(String style) {
    final m = Tile.materialFor(style);
    final type = m['type'] as String;
    String hex(Object? v, String d) => v is String && v.startsWith('#') ? v : d;
    return {
      'type': type,
      'c1': hex(m['base'] ?? m['color'], '#cccccc'),
      'c2': hex(m['vein'] ?? m['line'] ?? (m['chips'] is List ? (m['chips'] as List).first : null), '#888888'),
      'gloss': m['gloss'] ?? 0.3,
    };
  }

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final isNewItem = existing == null || existing['id'] == null;
    final d = Map<String, dynamic>.from(existing ??
        {'w': 60, 'h': 120, 'box': 1.44, 'style': 'marble', 'use': ['wall', 'floor'], 'inStock': true, 'isNew': true, 'active': true});
    final name = TextEditingController(text: d['name'] as String? ?? '');
    final price = TextEditingController(text: d['price'] == null ? '' : (d['price'] as num).toStringAsFixed(0));
    final box = TextEditingController(text: '${d['box'] ?? ''}');
    final finish = TextEditingController(text: d['finish'] as String? ?? '');
    final collection = TextEditingController(text: d['collection'] as String? ?? '');
    final country = TextEditingController(text: d['country'] as String? ?? '');
    final w0 = d['w'] as num, h0 = d['h'] as num;
    var sizeKey = '${w0 < h0 ? w0 : h0}x${w0 < h0 ? h0 : w0}';
    if (!kSizes.any((s) => '${s[0]}x${s[1]}' == sizeKey)) sizeKey = '60x120';
    var st = kStyles.containsKey(d['style']) ? d['style'] as String : 'solid';
    final use = Set<String>.from((d['use'] as List? ?? const []).cast<String>());
    var inStock = d['inStock'] != false, isNew = d['isNew'] == true, active = d['active'] != false;
    String? photo = d['image'] as String?;
    String? error;
    var busy = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        return AlertDialog(
          title: Text(isNewItem ? 'Новый товар' : 'Изменить товар'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 110, height: 110,
                      child: photo != null
                          ? Image.network('${widget.api.settings.serverUrl}$photo', fit: BoxFit.cover)
                          : Container(color: const Color(0xFF3A3631), child: const Icon(Icons.photo_outlined, size: 40, color: kGold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      OutlinedButton.icon(
                        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_outlined),
                        label: Text(photo == null ? 'Загрузить фото плитки' : 'Заменить фото'),
                        onPressed: busy
                            ? null
                            : () async {
                                final r = await FilePicker.platform.pickFiles(type: FileType.image);
                                final path = r?.files.single.path;
                                if (path == null) return;
                                setD(() => busy = true);
                                try {
                                  final wh = sizeKey.split('x').map(int.parse).toList();
                                  final url = await widget.api.uploadTilePhoto(path, wh[0], wh[1]);
                                  setD(() => photo = url);
                                } catch (e) {
                                  setD(() => error = '$e');
                                } finally {
                                  setD(() => busy = false);
                                }
                              },
                      ),
                      if (photo != null) TextButton(onPressed: () => setD(() => photo = null), child: const Text('Убрать фото')),
                      const Text('Одна плита ровно сверху, без бликов. Обрежется под размер сама.', style: TextStyle(fontSize: 12, color: Color(0xFFB5AC9F))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: sizeKey,
                      decoration: const InputDecoration(labelText: 'Размер'),
                      items: [for (final s in kSizes) DropdownMenuItem(value: '${s[0]}x${s[1]}', child: Text('${s[0]}×${s[1]} см'))],
                      onChanged: (v) => setD(() => sizeKey = v ?? sizeKey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: st,
                      decoration: const InputDecoration(labelText: 'Стиль'),
                      items: [for (final e in kStyles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => setD(() => st = v ?? st),
                    ),
                  ),
                ]),
                Row(children: [
                  Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена за 1 м², сум'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: box, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'м² в коробке'))),
                ]),
                Row(children: [
                  Expanded(child: TextField(controller: collection, decoration: const InputDecoration(labelText: 'Коллекция'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: country, decoration: const InputDecoration(labelText: 'Страна'))),
                ]),
                TextField(controller: finish, decoration: const InputDecoration(labelText: 'Поверхность (полированный, матовый…)')),
                const SizedBox(height: 12),
                const Text('Где можно класть'),
                Wrap(spacing: 8, children: [
                  for (final e in kUses.entries)
                    FilterChip(label: Text(e.value), selected: use.contains(e.key), onSelected: (v) => setD(() => v ? use.add(e.key) : use.remove(e.key))),
                ]),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('В наличии'), value: inStock, onChanged: (v) => setD(() => inStock = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Новинка'), value: isNew, onChanged: (v) => setD(() => isNew = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Показывать на сайте'), value: active, onChanged: (v) => setD(() => active = v)),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final pr = num.tryParse(price.text.replaceAll(' ', '').replaceAll(',', '.'));
                      final bx = num.tryParse(box.text.replaceAll(',', '.'));
                      if (name.text.trim().isEmpty) return setD(() => error = 'Укажите название');
                      if (pr == null || pr < 0) return setD(() => error = 'Укажите цену');
                      if (bx == null || bx <= 0) return setD(() => error = 'Укажите, сколько м² в коробке');
                      if (use.isEmpty) return setD(() => error = 'Отметьте, где можно класть');
                      final wh = sizeKey.split('x').map(int.parse).toList();
                      final body = <String, dynamic>{
                        'name': name.text.trim(), 'w': wh[0], 'h': wh[1], 'price': pr, 'box': bx,
                        'style': st, 'use': use.toList(), 'cats': Tile.catsFor(use.toList()),
                        'finish': finish.text.trim(), 'collection': collection.text.trim(), 'country': country.text.trim(),
                        'inStock': inStock, 'isNew': isNew, 'active': active, 'image': photo ?? '',
                        if (isNewItem || st != existing['style']) 'material': _look(st),
                        if (d['defaultLayout'] != null) 'defaultLayout': d['defaultLayout'],
                      };
                      setD(() => busy = true);
                      try {
                        await widget.api.saveProduct(body, id: isNewItem ? null : d['id'] as String);
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        setD(() { error = '$e'; busy = false; });
                      }
                    },
              child: const Text('Сохранить'),
            ),
          ],
        );
      }),
    );
    if (saved == true) {
      await _load();
      widget.onChanged?.call();
      _snack('Сохранено — товар уже на сайте и в программах');
    }
  }
}
