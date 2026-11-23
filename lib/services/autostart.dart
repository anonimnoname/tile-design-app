import 'dart:io';

import 'package:path/path.dart' as p;

/// Запуск программы вместе с Windows: ярлык-команда в папке «Автозагрузка».
class Autostart {
  static File? _file(String name) {
    final appData = Platform.environment['APPDATA'];
    if (!Platform.isWindows || appData == null) return null;
    return File(p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup', '$name.cmd'));
  }

  static bool supported(String name) => _file(name) != null;

  static bool isOn(String name) => _file(name)?.existsSync() ?? false;

  static Future<void> set(String name, bool on) async {
    final f = _file(name);
    if (f == null) return;
    if (on) {
      await f.writeAsString('@echo off\r\nstart "" "${Platform.resolvedExecutable}"\r\n');
    } else if (await f.exists()) {
      await f.delete();
    }
  }
}
