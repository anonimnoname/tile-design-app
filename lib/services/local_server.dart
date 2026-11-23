import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'app_settings.dart';
import 'catalog_store.dart';

/// Маленький сервер внутри программы: отдаёт конструктор (assets/web),
/// каталог (свой или с сайта, с кэшем — работает без интернета) и фото плитки.
class LocalServer {
  LocalServer(this.settings, this.store);
  final AppSettings settings;
  final CatalogStore store;
  HttpServer? _server;

  int get port => _server?.port ?? 0;

  /// Постоянный порт — чтобы браузер помнил сохранённые комнаты между запусками.
  Future<int> start({int preferred = 47821}) async {
    for (var port = preferred; port < preferred + 10 && _server == null; port++) {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } on SocketException {
        // порт занят — пробуем следующий
      }
    }
    _server ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((r) => _handle(r).catchError((_) {}));
    return port;
  }

  Future<void> stop() async => _server?.close(force: true);

  String url({bool tv = false}) => 'http://127.0.0.1:$port/?app=1${tv ? '&tv=1' : ''}#/constructor';

  Future<void> _handle(HttpRequest req) async {
    final path = Uri.decodeComponent(req.uri.path);
    try {
      if (path == '/api/catalog') return await _catalog(req);
      if (path.startsWith('/uploads/')) return await _image(req, p.basename(path));
      if (path.startsWith('/api/')) {
        return _send(req, 404, 'application/json; charset=utf-8', utf8.encode('{"error":"Недоступно в программе"}'));
      }
      final rel = path == '/' ? 'index.html' : path.substring(1);
      if (rel.contains('..')) return _send(req, 403, 'text/plain', utf8.encode('Forbidden'));
      final data = await rootBundle.load('assets/web/$rel');
      return _send(req, 200, _type(rel), data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      return _send(req, 404, 'text/plain; charset=utf-8', utf8.encode('Not found'));
    }
  }

  /// Каталог: с сайта (если указан адрес) с кэшем на случай без интернета, иначе свой.
  Future<void> _catalog(HttpRequest req) async {
    String body;
    if (settings.usesServer) {
      body = await fetchSiteCatalog() ?? await store.readCache() ?? store.localCatalogJson();
    } else {
      body = store.localCatalogJson();
    }
    return _send(req, 200, 'application/json; charset=utf-8', utf8.encode(body));
  }

  /// Загружает каталог с сайта и сохраняет в кэш. null — сайт недоступен.
  Future<String?> fetchSiteCatalog() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final rq = await client.getUrl(Uri.parse('${settings.serverUrl}/api/catalog'));
      final rs = await rq.close().timeout(const Duration(seconds: 10));
      if (rs.statusCode != 200) return null;
      final body = await rs.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      if (j['products'] is! List) return null;
      await store.writeCache(body);
      return body;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Фото: своё — из папки программы; с сайта — скачиваем один раз и храним.
  Future<void> _image(HttpRequest req, String name) async {
    if (!RegExp(r'^[\w.-]+$').hasMatch(name)) return _send(req, 400, 'text/plain', utf8.encode('Bad name'));
    var file = File(p.join(settings.imagesDir.path, name));
    if (!await file.exists() && settings.usesServer) {
      file = File(p.join(settings.remoteImagesDir.path, name));
      if (!await file.exists()) {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
        try {
          final rq = await client.getUrl(Uri.parse('${settings.serverUrl}/uploads/$name'));
          final rs = await rq.close().timeout(const Duration(seconds: 20));
          if (rs.statusCode == 200) {
            final bytes = await rs.fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d));
            await file.writeAsBytes(bytes.takeBytes());
          }
        } catch (_) {
          // нет интернета — фото появится, когда будет связь
        } finally {
          client.close(force: true);
        }
      }
    }
    if (!await file.exists()) return _send(req, 404, 'text/plain', utf8.encode('Not found'));
    return _send(req, 200, _type(name), await file.readAsBytes());
  }

  void _send(HttpRequest req, int code, String type, List<int> body) {
    final r = req.response;
    r.statusCode = code;
    r.headers.set(HttpHeaders.contentTypeHeader, type);
    r.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    r.add(body);
    r.close();
  }

  static String _type(String name) {
    switch (p.extension(name).toLowerCase()) {
      case '.html':
        return 'text/html; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.js':
        return 'text/javascript; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.svg':
        return 'image/svg+xml';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
