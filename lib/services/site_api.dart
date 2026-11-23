import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'app_settings.dart';

/// Ошибка от сайта с понятным текстом (например «Неверный пароль»).
class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Связь программы с сайтом: одна база товаров и заказов для сайта и обоих ноутбуков.
/// Вход — тем же паролем, что и админка сайта.
class SiteApi {
  SiteApi(this.settings);
  final AppSettings settings;

  bool get loggedIn => settings.sid.isNotEmpty;

  Future<dynamic> _req(String method, String path, [Object? body]) async {
    if (!settings.usesServer) throw ApiException(0, 'Не указан адрес сайта (Настройки)');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final rq = await client.openUrl(method, Uri.parse('${settings.serverUrl}/api/$path'));
      if (settings.sid.isNotEmpty) rq.headers.set(HttpHeaders.cookieHeader, 'sid=${settings.sid}');
      if (body != null) {
        rq.headers.contentType = ContentType.json;
        rq.add(utf8.encode(jsonEncode(body)));
      }
      final rs = await rq.close().timeout(const Duration(seconds: 30));
      for (final c in rs.cookies) {
        if (c.name == 'sid') {
          settings.sid = c.value;
          await settings.save();
        }
      }
      final text = await rs.transform(utf8.decoder).join();
      final j = text.isEmpty ? null : jsonDecode(text);
      if (rs.statusCode == 401 && path != 'login') {
        settings.sid = '';
        await settings.save();
      }
      if (rs.statusCode >= 400) {
        throw ApiException(rs.statusCode, j is Map && j['error'] is String ? j['error'] as String : 'Ошибка ${rs.statusCode}');
      }
      return j;
    } on SocketException {
      throw ApiException(0, 'Нет связи с сайтом. Проверьте интернет.');
    } on HandshakeException {
      throw ApiException(0, 'Не удалось установить защищённое соединение с сайтом.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> login(String password) async => _req('POST', 'login', {'password': password});
  Future<void> logout() async {
    try {
      await _req('POST', 'logout');
    } catch (_) {}
    settings.sid = '';
    await settings.save();
  }

  Future<bool> checkSession() async {
    if (!loggedIn) return false;
    try {
      await _req('GET', 'admin/me');
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) return false;
      rethrow;
    }
  }

  // ---- заказы ----
  Future<List<Map<String, dynamic>>> orders() async =>
      ((await _req('GET', 'admin/orders')) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<Map<String, dynamic>> patchOrder(int id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _req('PATCH', 'admin/orders/$id', body) as Map);

  // ---- товары ----
  Future<List<Map<String, dynamic>>> products() async =>
      ((await _req('GET', 'admin/products')) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<Map<String, dynamic>> saveProduct(Map<String, dynamic> body, {String? id}) async =>
      Map<String, dynamic>.from(await _req(id == null ? 'POST' : 'PUT', id == null ? 'admin/products' : 'admin/products/${Uri.encodeComponent(id)}', body) as Map);
  Future<Map<String, dynamic>> patchProduct(String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _req('PATCH', 'admin/products/${Uri.encodeComponent(id)}', body) as Map);
  Future<void> deleteProduct(String id) async => _req('DELETE', 'admin/products/${Uri.encodeComponent(id)}');

  /// Фото плитки: обрезаем по пропорциям плитки, уменьшаем до 1024 px, загружаем на сайт.
  /// Возвращает адрес «/uploads/…».
  Future<String> uploadTilePhoto(String path, num w, num h) async {
    final png = await cropToTile(await File(path).readAsBytes(), w / h);
    final r = await _req('POST', 'admin/upload', {'dataUrl': 'data:image/png;base64,${base64Encode(png)}'}) as Map;
    return r['url'] as String;
  }

  static Future<Uint8List> cropToTile(Uint8List bytes, num aspect, {int maxSide = 1024}) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final img = (await codec.getNextFrame()).image;
    var sw = img.width.toDouble(), sh = img.height.toDouble();
    if (sw / sh > aspect) {
      sw = sh * aspect;
    } else {
      sh = sw / aspect;
    }
    final sx = (img.width - sw) / 2, sy = (img.height - sh) / 2;
    final k = [1.0, maxSide / (sw > sh ? sw : sh)].reduce((a, b) => a < b ? a : b);
    final ow = (sw * k).round(), oh = (sh * k).round();
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawImageRect(img, ui.Rect.fromLTWH(sx, sy, sw, sh), ui.Rect.fromLTWH(0, 0, ow.toDouble(), oh.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high);
    final out = await rec.endRecording().toImage(ow, oh);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  // ---- настройки магазина ----
  Future<Map<String, dynamic>> shopSettings() async => Map<String, dynamic>.from(await _req('GET', 'admin/settings') as Map);
  Future<Map<String, dynamic>> saveShopSettings(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _req('PUT', 'admin/settings', body) as Map);
}
