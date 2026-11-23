import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Настройки программы и папки с данными (каталог, фото, профиль браузера).
class AppSettings {
  AppSettings._(this.dir);

  /// Папка программы в профиле Windows (%APPDATA%\...\tile_design_app).
  final Directory dir;

  /// Адрес сайта магазина, например https://3dkamron.uz. Пусто — каталог ведётся в программе.
  String serverUrl = '';

  /// Секретный адрес админки сайта (то, что задано в ADMIN_PATH на сервере).
  String adminPath = 'admin';

  /// Программа «Заказы»: открывать окно заказов сразу при запуске.
  bool autoOpen = true;

  /// Вход в админку сайта (запоминается на 30 дней, как в браузере).
  String sid = '';

  /// Номер последнего заказа, о котором уже уведомили.
  int lastOrderId = 0;

  File get _file => File(p.join(dir.path, 'settings.json'));
  Directory get imagesDir => Directory(p.join(dir.path, 'images'));
  Directory get remoteImagesDir => Directory(p.join(dir.path, 'remote_images'));
  Directory get browserProfileDir => Directory(p.join(dir.path, 'browser'));

  bool get usesServer => serverUrl.isNotEmpty;

  /// [sub] — отдельная папка для второй программы («orders»), чтобы настройки не смешивались.
  static Future<AppSettings> load({Directory? baseDir, String? sub}) async {
    var dir = baseDir ?? await getApplicationSupportDirectory();
    if (sub != null) dir = Directory(p.join(dir.path, sub));
    await dir.create(recursive: true);
    final s = AppSettings._(dir);
    await s.imagesDir.create(recursive: true);
    await s.remoteImagesDir.create(recursive: true);
    try {
      final j = jsonDecode(await s._file.readAsString()) as Map<String, dynamic>;
      s.serverUrl = normalizeUrl(j['serverUrl'] as String? ?? '');
      s.adminPath = (j['adminPath'] as String? ?? 'admin').trim();
      s.autoOpen = j['autoOpen'] as bool? ?? true;
      s.sid = j['sid'] as String? ?? '';
      s.lastOrderId = (j['lastOrderId'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // первый запуск — настройки по умолчанию
    }
    return s;
  }

  Future<void> save() async {
    await _file.writeAsString(jsonEncode({'serverUrl': serverUrl, 'adminPath': adminPath, 'autoOpen': autoOpen, 'sid': sid, 'lastOrderId': lastOrderId}));
  }

  /// «3dkamron.uz/» → «https://3dkamron.uz»
  static String normalizeUrl(String v) {
    var s = v.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String get adminUrl => '$serverUrl/${adminPath.replaceAll('/', '')}';
}
