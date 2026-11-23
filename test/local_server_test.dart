import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tile_design_app/services/app_settings.dart';
import 'package:tile_design_app/services/catalog_store.dart';
import 'package:tile_design_app/services/invoice_pdf.dart';
import 'package:tile_design_app/services/local_server.dart';

Future<(int, String)> _get(int port, String path) async {
  final c = HttpClient();
  final rs = await (await c.getUrl(Uri.parse('http://127.0.0.1:$port$path'))).close();
  final body = await rs.transform(const Utf8Decoder(allowMalformed: true)).join();
  c.close();
  return (rs.statusCode, body);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('отдаёт конструктор, свой каталог и фото', () async {
    HttpOverrides.global = null; // настоящая сеть на 127.0.0.1, а не заглушка тестов
    final dir = await Directory.systemTemp.createTemp('kamron');
    final settings = await AppSettings.load(baseDir: dir);
    final store = CatalogStore(settings);
    await store.load();
    // своя плитка с фото
    final photo = File('${dir.path}/p.jpg')..writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
    final img = await store.importPhoto(photo.path);
    await store.upsert(Tile({
      'id': CatalogStore.newId(), 'name': 'Тест мрамор', 'w': 60, 'h': 120, 'price': 100000, 'box': 1.44,
      'style': 'marble', 'use': ['wall'], 'cats': ['bath'], 'inStock': true, 'active': true, 'image': img,
      'material': Tile.materialFor('marble'),
    }));

    final server = LocalServer(settings, store);
    final port = await server.start(preferred: 48521);

    final (c1, html) = await _get(port, '/');
    expect(c1, 200);
    expect(html, contains('shared/loader.js'));

    final (c2, js) = await _get(port, '/constructor/constructor.js');
    expect(c2, 200);
    expect(js.length, greaterThan(1000));

    final (c3, cat) = await _get(port, '/api/catalog');
    expect(c3, 200);
    final products = (jsonDecode(cat) as Map)['products'] as List;
    expect(products.single['name'], 'Тест мрамор');

    final (c4, _) = await _get(port, img);
    expect(c4, 200);

    final (c5, _) = await _get(port, '/../settings.json');
    expect(c5, isNot(200));

    // накладная: запрос из конструктора доходит до печати
    Map<String, dynamic>? printed;
    server.onInvoice = (d) async => printed = d;
    final c = HttpClient();
    final rq = await c.postUrl(Uri.parse('http://127.0.0.1:$port/app/invoice'));
    rq.headers.contentType = ContentType.json;
    rq.write(jsonEncode({'shop': '3D Kamron', 'items': [], 'total': 1000}));
    final rs = await rq.close();
    expect(rs.statusCode, 200);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(printed?['shop'], '3D Kamron');
    c.close();

    expect(server.url(), contains('?app=1'));
    await server.stop();
  });

  test('PDF накладной собирается со шрифтом из программы', () async {
    final bytes = await InvoicePdf.build({
      'shop': '3D Kamron', 'phone': '+998 90 502 87 22', 'address': 'Buyuk ipak yoli 11', 'currency': 'сум',
      'number': '261123-1200', 'date': '23.11.2026', 'dims': 'Ванная: 3 м × 2.6 м', 'grout': 'Затирка: белая, шов 2 мм',
      'materials': [{'label': 'Стена 1', 'name': 'Калакатта', 'size': '60×120', 'price': 245000}],
      'items': [{'name': 'Стены', 'pieces': 34, 'boxes': 17, 'area': 24.48, 'sum': 5997600}],
      'total': 5997600, 'image': '',
    });
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });
}
