import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart' show kDark2, kGold;
import '../../services/browser_launcher.dart';
import '../../services/order_watcher.dart';
import '../../services/site_api.dart';

const kStatuses = {
  'new': 'Новый',
  'confirmed': 'Подтверждён',
  'paid': 'Оплачен',
  'delivering': 'В доставке',
  'done': 'Выполнен',
  'cancelled': 'Отменён',
};
const _statusColor = {
  'new': Color(0xFFC9A77A),
  'confirmed': Color(0xFF5B9BD5),
  'paid': Color(0xFF1F9D55),
  'delivering': Color(0xFF5B9BD5),
  'done': Color(0xFF1F9D55),
  'cancelled': Color(0xFF6E685E),
};

/// Заказы с сайта: приходят сами (каждые 20 секунд), новые — с уведомлением Windows.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.api, required this.watcher});
  final SiteApi api;
  final OrderWatcher watcher;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String filter = 'active';
  String query = '';
  Map<String, dynamic> shop = {};

  @override
  void initState() {
    super.initState();
    widget.watcher.addListener(_changed);
    widget.api.shopSettings().then((v) => setState(() => shop = v)).catchError((_) {});
  }

  @override
  void dispose() {
    widget.watcher.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  List<Map<String, dynamic>> get _list {
    final q = query.trim().toLowerCase();
    return widget.watcher.orders.where((o) {
      final st = o['status'] as String;
      final okStatus = filter == 'all' || (filter == 'active' ? st != 'done' && st != 'cancelled' : st == filter);
      if (!okStatus) return false;
      if (q.isEmpty) return true;
      final c = o['customer'] as Map, r = o['recipient'] as Map, a = o['address'] as Map;
      return '№${o['id']} ${c['name']} ${c['phone']} ${r['name']} ${r['phone']} ${a['city']} ${a['street']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _setStatus(Map<String, dynamic> o, String st) async {
    try {
      final u = await widget.api.patchOrder((o['id'] as num).toInt(), {'status': st});
      o['status'] = u['status'];
      setState(() {});
      _snack('Статус: ${kStatuses[st]}');
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.watcher, list = _list;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск: номер, имя, телефон, город', border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(tooltip: 'Обновить', onPressed: () => w.refresh(), icon: const Icon(Icons.refresh)),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          for (final f in [['active', 'Текущие'], ['new', 'Новые'], ['paid', 'Оплаченные'], ['done', 'Выполненные'], ['cancelled', 'Отменённые'], ['all', 'Все']])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(f[1]), selected: filter == f[0], onSelected: (_) => setState(() => filter = f[0])),
            ),
        ]),
      ),
      if (w.error != null)
        Padding(padding: const EdgeInsets.all(12), child: Text(w.error!, style: const TextStyle(color: Colors.redAccent))),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('Заказов нет'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _card(list[i]),
              ),
      ),
    ]);
  }

  Widget _card(Map<String, dynamic> o) {
    final c = o['customer'] as Map, r = o['recipient'] as Map, a = o['address'] as Map;
    final st = o['status'] as String;
    final when = DateTime.tryParse(o['createdAt'] as String? ?? '')?.toLocal();
    final text = OrderWatcher.confirmText(o, shop);
    final phone = (c['phone'] as String).replaceAll('+', '');
    return Card(
      color: kDark2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _statusColor[st] ?? kGold, width: 1.2)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('№${o['id']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            if (when != null)
              Text('${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Color(0xFFB5AC9F))),
            const Spacer(),
            DropdownButton<String>(
              value: kStatuses.containsKey(st) ? st : 'new',
              items: [for (final e in kStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => v == null ? null : _setStatus(o, v),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 32, runSpacing: 8, children: [
            _who('Заказчик — подтвердить по этому номеру', '${c['name']}', '${c['phone']}', 'Связь: ${c['contact'] ?? 'любая'}'),
            _who('Получатель, оплата при доставке', '${r['name']}', '${r['phone']}', '${a['city']}, ${a['street']}'),
          ]),
          const Divider(height: 22),
          for (final it in (o['items'] as List).cast<Map>())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text('${it['name']} ${it['size']}${(it['note'] ?? '') != '' ? ' · ${it['note']}' : ''}')),
                Text('${it['boxes']} кор. · ${it['m2']} м²   '),
                Text('${money(it['sum'] as num)} сум', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: Text('Итого: ${money(o['total'] as num)} сум', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if ((o['comment'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 6), child: Text('💬 ${o['comment']}')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1F9D55)),
              onPressed: () => BrowserLauncher.openDefault('https://wa.me/$phone?text=${Uri.encodeComponent(text)}'),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Подтвердить в WhatsApp'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                await BrowserLauncher.openDefault('https://t.me/${c['phone']}');
                _snack('Сообщение скопировано — вставьте его в чат Telegram (Ctrl+V)');
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Подтвердить в Telegram'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                _snack('Сообщение скопировано');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Скопировать сообщение'),
            ),
            for (final l in ((o['links'] as List?) ?? const []).cast<String>())
              TextButton.icon(onPressed: () => BrowserLauncher.openDefault(l), icon: const Icon(Icons.view_in_ar), label: const Text('Подборка в 3D')),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: o['adminNote'] as String? ?? '',
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Заметка (видно только вам)', isDense: true, border: OutlineInputBorder()),
            onFieldSubmitted: (v) => _saveNote(o, v),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (v) => o['_note'] = v,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _saveNote(o, (o['_note'] ?? o['adminNote'] ?? '') as String), child: const Text('Сохранить заметку')),
          ),
        ]),
      ),
    );
  }

  Future<void> _saveNote(Map<String, dynamic> o, String v) async {
    try {
      await widget.api.patchOrder((o['id'] as num).toInt(), {'adminNote': v});
      o['adminNote'] = v;
      _snack('Заметка сохранена');
    } catch (e) {
      _snack('$e');
    }
  }

  Widget _who(String label, String name, String phone, String extra) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFFB5AC9F), letterSpacing: .5)),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SelectableText(phone, style: const TextStyle(color: kGold, fontWeight: FontWeight.w700)),
          Text(extra, style: const TextStyle(color: Color(0xFFB5AC9F))),
        ]),
      );
}
