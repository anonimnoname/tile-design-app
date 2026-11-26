import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_settings.dart';

/// Форматы и стили — те же, что на сайте.
const kSizes = [
  [60, 120],
  [75, 150],
  [80, 135],
];
const kStyles = {
  'marble': 'Мрамор',
  'onyx': 'Оникс',
  'stone': 'Камень и травертин',
  'concrete': 'Бетон и микроцемент',
  'terrazzo': 'Терраццо',
  'solid': 'Однотонные',
};
const kUses = {'wall': 'Стены', 'floor': 'Пол', 'plinth': 'Цоколь', 'outdoor': 'Двор / улица'};

/// Плитка в том же формате, что и в каталоге сайта (JSON).
class Tile {
  Tile(this.data);
  final Map<String, dynamic> data;

  String get id => data['id'] as String;
  String get name => (data['name'] ?? '') as String;
  num get w => (data['w'] ?? 60) as num;
  num get h => (data['h'] ?? 120) as num;
  num get price => (data['price'] ?? 0) as num;
  num get box => (data['box'] ?? 1.44) as num;
  String get style => (data['style'] ?? 'solid') as String;
  bool get inStock => data['inStock'] != false;
  bool get isNew => data['isNew'] == true;
  List<String> get use => ((data['use'] ?? const []) as List).cast<String>();

  /// Все узоры модели: «/uploads/…».
  List<String> get images =>
      (data['images'] as List?)?.cast<String>() ?? (data['image'] is String ? [data['image'] as String] : const <String>[]);

  /// Путь к фото на диске (для своих плиток) — из «/uploads/имя». Берётся первый узор.
  String? imageFile(AppSettings s) {
    final img = images.isEmpty ? null : images.first;
    if (img == null || !img.startsWith('/uploads/')) return null;
    return p.join(s.imagesDir.path, img.substring('/uploads/'.length));
  }

  static Map<String, dynamic> materialFor(String style) {
    switch (style) {
      case 'marble':
        return {'type': 'marble', 'base': '#f1efea', 'vein': '#8b8e93', 'veinAlpha': 0.55, 'gloss': 0.9};
      case 'onyx':
        return {'type': 'marble', 'base': '#e6cfa6', 'vein': '#a9773d', 'veinAlpha': 0.5, 'gloss': 1, 'clouds': '#d2a96b'};
      case 'stone':
        return {'type': 'travertine', 'base': '#ddcfb8', 'line': '#b9a588', 'gloss': 0.15};
      case 'concrete':
        return {'type': 'stone', 'base': '#9c9b97', 'speck': 0.4, 'gloss': 0.05};
      case 'terrazzo':
        return {'type': 'terrazzo', 'base': '#eeebe5', 'chips': ['#c9b9a6', '#8a8d91', '#d98f6f', '#4f5559'], 'gloss': 0.25};
      default:
        return {'type': 'solid', 'color': '#ddd6ca', 'gloss': 0.2};
    }
  }

  /// Разделы каталога сайта по тому, где кладут плитку.
  static List<String> catsFor(List<String> use) {
    final c = <String>{'universal'};
    if (use.contains('wall')) c.addAll(['bath', 'kitchen']);
    if (use.contains('floor')) c.add('floor');
    if (use.contains('plinth') || use.contains('outdoor')) c.add('outdoor');
    return c.toList();
  }
}

/// Свой каталог программы: catalog.json + папка с фото. Плюс кэш каталога с сайта.
class CatalogStore {
  CatalogStore(this.settings);
  final AppSettings settings;
  final List<Tile> tiles = [];

  File get _file => File(p.join(settings.dir.path, 'catalog.json'));
  File get _cache => File(p.join(settings.dir.path, 'site_catalog_cache.json'));
  DateTime? cacheTime;

  Future<void> load() async {
    tiles.clear();
    if (await _file.exists()) {
      try {
        final list = jsonDecode(await _file.readAsString()) as List;
        tiles.addAll(list.map((e) => Tile(Map<String, dynamic>.from(e as Map))));
      } catch (_) {
        // повреждённый файл — начинаем с пустого каталога
      }
    } else {
      await _importOldDatabase();
    }
    if (await _cache.exists()) cacheTime = await _cache.lastModified();
  }

  Future<void> save() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(tiles.map((t) => t.data).toList()));
    await tmp.rename(_file.path);
  }

  static String newId() => 'local-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

  /// Копирует фото в папку программы, возвращает «/uploads/имя».
  Future<String> importPhoto(String path) async {
    final ext = p.extension(path).toLowerCase();
    final safeExt = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext) ? ext : '.jpg';
    final name = '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(99999)}$safeExt';
    await File(path).copy(p.join(settings.imagesDir.path, name));
    return '/uploads/$name';
  }

  Future<void> upsert(Tile t) async {
    final i = tiles.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tiles[i] = t;
    } else {
      tiles.insert(0, t);
    }
    await save();
  }

  Future<void> remove(Tile t) async {
    tiles.removeWhere((x) => x.id == t.id);
    for (final u in t.images) {
      if (tiles.any((x) => x.images.contains(u))) continue;
      final f = Tile({'image': u}).imageFile(settings);
      if (f == null) continue;
      try {
        await File(f).delete();
      } catch (_) {}
    }
    await save();
  }

  /// JSON для конструктора (тот же формат, что /api/catalog на сайте).
  String localCatalogJson() => jsonEncode({
        'products': tiles.where((t) => t.data['active'] != false).map((t) => t.data).toList(),
        'settings': <String, dynamic>{},
      });

  Future<String?> readCache() async => await _cache.exists() ? _cache.readAsString() : null;

  Future<void> writeCache(String body) async {
    await _cache.writeAsString(body);
    cacheTime = DateTime.now();
  }

  /// Сколько товаров в кэше каталога с сайта.
  Future<int> cachedCount() async {
    try {
      final j = jsonDecode(await readCache() ?? '{}') as Map;
      return (j['products'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Перенос плитки из старой версии программы (SQLite design_tiles_v2.db).
  Future<void> _importOldDatabase() async {
    try {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final candidates = <String>[
        p.join(await factory.getDatabasesPath(), 'design_tiles_v2.db'),
        p.join(Directory.current.path, '.dart_tool', 'sqflite_common_ffi', 'databases', 'design_tiles_v2.db'),
        p.join(p.dirname(Platform.resolvedExecutable), '.dart_tool', 'sqflite_common_ffi', 'databases', 'design_tiles_v2.db'),
      ];
      for (final path in candidates) {
        if (!await File(path).exists()) continue;
        final db = await factory.openDatabase(path, options: OpenDatabaseOptions(readOnly: true));
        final rows = await db.query('tiles');
        await db.close();
        for (final r in rows) {
          final w = (r['widthCm'] as num?) ?? 60, h = (r['heightCm'] as num?) ?? 120;
          final data = <String, dynamic>{
            'id': newId(),
            'name': r['name'] ?? 'Плитка',
            'w': w, 'h': h,
            'price': (r['pricePerSquareMeter'] as num?) ?? 0,
            'box': double.parse((w * h / 10000 * 2).toStringAsFixed(2)),
            'style': 'solid',
            'use': ['wall', 'floor'],
            'cats': Tile.catsFor(['wall', 'floor']),
            'inStock': true, 'active': true,
            'finish': '', 'country': '',
            'material': Tile.materialFor('solid'),
          };
          final img = (r['imagePath'] as String?) ?? '';
          if (img.isNotEmpty && await File(img).exists()) data['image'] = await importPhoto(img);
          tiles.add(Tile(data));
        }
        if (tiles.isNotEmpty) await save();
        return;
      }
    } catch (_) {
      // старой базы нет или она недоступна — ничего страшного
    }
  }
}
