// Проверка связи программы с настоящим сайтом. Запускается, только если задан адрес:
//   SITE_URL=http://127.0.0.1:3000 SITE_PASSWORD=... flutter test test/site_api_live_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:tile_design_app/services/app_settings.dart';
import 'package:tile_design_app/services/order_watcher.dart';
import 'package:tile_design_app/services/site_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final url = Platform.environment['SITE_URL'];
  final pw = Platform.environment['SITE_PASSWORD'] ?? '';

  test('одна база с сайтом: вход, товары, фото, заказы', () async {
    HttpOverrides.global = null;
    final dir = await Directory.systemTemp.createTemp('kamron-live');
    final s = await AppSettings.load(baseDir: dir);
    s.serverUrl = url!;
    final api = SiteApi(s);

    expect(() => api.login('wrong-password'), throwsA(isA<ApiException>()));
    await api.login(pw);
    expect(s.sid, isNotEmpty);
    expect(await api.checkSession(), isTrue);

    final before = await api.products();
    // фото: делаем картинку 300×300 и загружаем как плитку 60×120 (обрежется до 1:2)
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 300, 300), ui.Paint()..color = const ui.Color(0xFFC9A77A));
    final img = await rec.endRecording().toImage(300, 300);
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final f = File('${dir.path}/photo.png')..writeAsBytesSync(png);
    final cropped = await SiteApi.cropToTile(Uint8List.fromList(png), 60 / 120);
    final ci = await (await ui.instantiateImageCodec(cropped)).getNextFrame();
    expect(ci.image.width * 2, ci.image.height);
    final photo = await api.uploadTilePhoto(f.path, 60, 120);
    expect(photo, startsWith('/uploads/'));
    final photo2 = await api.uploadTilePhoto(f.path, 60, 120);

    final p = await api.saveProduct({
      'name': 'Тест из программы', 'w': 60, 'h': 120, 'price': 111000, 'box': 1.44, 'style': 'marble',
      'use': ['wall', 'floor'], 'cats': ['universal'], 'inStock': true, 'isNew': true, 'active': true, 'images': [photo, photo2], 'image': photo,
      'material': {'type': 'marble', 'c1': '#f1efea', 'c2': '#8b8e93', 'gloss': 0.9},
    });
    expect((await api.products()).length, before.length + 1);
    expect((p['images'] as List).length, 2); // несколько узоров одной модели
    final u = await api.patchProduct(p['id'] as String, {'price': 120000, 'inStock': false});
    expect(u['price'], 120000);
    expect(u['inStock'], false);

    final watcher = OrderWatcher(api);
    await watcher.refresh(notify: false);
    expect(watcher.error, isNull);
    stdout.writeln('заказов: ${watcher.orders.length}, новых: ${watcher.newCount}');
    if (watcher.orders.isNotEmpty) {
      final o = watcher.orders.first;
      final txt = OrderWatcher.confirmText(o, await api.shopSettings());
      expect(txt, contains('№${o['id']}'));
      final upd = await api.patchOrder((o['id'] as num).toInt(), {'status': 'confirmed', 'adminNote': 'проверено из программы'});
      expect(upd['status'], 'confirmed');
    }
    await api.deleteProduct(p['id'] as String);
    expect((await api.products()).length, before.length);
    await api.logout();
    expect(s.sid, isEmpty);
  }, skip: url == null ? 'SITE_URL не задан' : false);
}
