import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'site_api.dart';

String money(num v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

/// Каждые 20 секунд спрашивает сайт о заказах. Новый заказ — уведомление в углу экрана
/// Windows и обновление списка в программе.
class OrderWatcher extends ChangeNotifier {
  OrderWatcher(this.api);
  final SiteApi api;
  final _notes = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _notesReady = false;

  List<Map<String, dynamic>> orders = [];
  String? error;
  DateTime? updated;
  void Function()? onNotificationTap;

  int get newCount => orders.where((o) => o['status'] == 'new').length;

  Future<void> start() async {
    await _initNotes();
    await refresh(notify: false);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }

  void stop() => _timer?.cancel();

  Future<void> _initNotes() async {
    if (_notesReady) return;
    try {
      await _notes.initialize(
        settings: const InitializationSettings(
          windows: WindowsInitializationSettings(
            appName: '3D Kamron Заказы',
            appUserModelId: 'Kamron.3DKamron.Orders',
            guid: '7c1f5b0e-3d6a-4c2b-9b1a-6a2f4f3e8d11',
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
          macOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
      );
      _notesReady = true;
    } catch (_) {
      // уведомления недоступны — список в программе всё равно обновляется
    }
  }

  Future<void> refresh({bool notify = true}) async {
    try {
      final list = await api.orders();
      error = null;
      updated = DateTime.now();
      final maxId = list.fold<int>(0, (m, o) => (o['id'] as num).toInt() > m ? (o['id'] as num).toInt() : m);
      final last = api.settings.lastOrderId;
      final fresh = list.where((o) => (o['id'] as num).toInt() > last).toList();
      orders = list;
      if (maxId > last) {
        api.settings.lastOrderId = maxId;
        await api.settings.save();
      }
      if (notify && last > 0) {
        for (final o in fresh.reversed) {
          await _show(o);
        }
      }
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> _show(Map<String, dynamic> o) async {
    if (!_notesReady) return;
    final c = o['customer'] as Map, a = o['address'] as Map;
    try {
      await _notes.show(
        id: (o['id'] as num).toInt(),
        title: 'Новый заказ №${o['id']} — ${money(o['total'] as num)} сум',
        body: '${c['name']}, ${c['phone']} → ${a['city']}. ${(o['items'] as List).length} поз.',
        notificationDetails: const NotificationDetails(windows: WindowsNotificationDetails()),
      );
    } catch (_) {}
  }

  /// Сообщение клиенту для подтверждения (то же, что в веб-админке).
  static String confirmText(Map<String, dynamic> o, Map<String, dynamic> shop) {
    final cur = shop['currency'] ?? 'сум';
    final c = o['customer'] as Map, r = o['recipient'] as Map, a = o['address'] as Map;
    final card = (shop['payCard'] ?? '') as String, holder = (shop['payCardHolder'] ?? '') as String, bank = (shop['payBank'] ?? '') as String;
    return [
      'Здравствуйте, ${c['name']}! Это ${shop['name'] ?? 'магазин'}.',
      'Вы оформили заказ №${o['id']} на сайте:',
      for (final i in (o['items'] as List).cast<Map>()) '• ${i['name']} ${i['size']} — ${i['boxes']} кор. (${i['m2']} м²) — ${money(i['sum'] as num)} $cur',
      'Итого: ${money(o['total'] as num)} $cur',
      'Доставка: ${a['city']}, ${a['street']}. Получатель: ${r['name']}, ${r['phone']}.',
      '',
      'Подтверждаете заказ?',
      card.isNotEmpty || bank.isNotEmpty ? 'Оплатить можно при получении или переводом:' : 'Оплата при получении.',
      if (card.isNotEmpty) 'Карта: $card${holder.isNotEmpty ? ' ($holder)' : ''}',
      if (bank.isNotEmpty) 'Счёт: $bank',
      'После подтверждения сообщим дату доставки.',
    ].join('\n');
  }
}
