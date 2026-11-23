import 'dart:io';

/// Открывает конструктор в отдельном окне Edge/Chrome без адресной строки
/// (режим приложения). Edge есть в каждой Windows 10/11.
class BrowserLauncher {
  static List<String> _windowsCandidates() {
    final env = Platform.environment;
    final roots = [env['ProgramFiles(x86)'], env['ProgramFiles'], env['LOCALAPPDATA']].whereType<String>();
    return [
      for (final r in roots) '$r\\Microsoft\\Edge\\Application\\msedge.exe',
      for (final r in roots) '$r\\Google\\Chrome\\Application\\chrome.exe',
    ];
  }

  /// [fullscreen] — для показа на телевизоре.
  static Future<void> openApp(String url, {required String profileDir, bool fullscreen = false}) async {
    final args = [
      '--app=$url',
      '--user-data-dir=$profileDir',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-features=Translate',
      fullscreen ? '--start-fullscreen' : '--start-maximized',
    ];
    if (Platform.isWindows) {
      for (final exe in _windowsCandidates()) {
        if (File(exe).existsSync()) {
          await Process.start(exe, args, mode: ProcessStartMode.detached);
          return;
        }
      }
    } else if (Platform.isMacOS) {
      for (final app in ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge']) {
        if (File(app).existsSync()) {
          await Process.start(app, args, mode: ProcessStartMode.detached);
          return;
        }
      }
    } else if (Platform.isLinux) {
      for (final exe in ['google-chrome', 'chromium', 'chromium-browser', 'microsoft-edge']) {
        try {
          await Process.start(exe, args, mode: ProcessStartMode.detached);
          return;
        } catch (_) {}
      }
    }
    await openDefault(url);
  }

  /// Обычный браузер по умолчанию (например, для админки сайта).
  static Future<void> openDefault(String url) async {
    if (Platform.isWindows) {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', url], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url], mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
    }
  }
}
