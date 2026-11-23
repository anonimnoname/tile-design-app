import 'package:flutter/material.dart';

import '../../services/site_api.dart';

/// Настройки магазина на сайте: телефон, адрес, реквизиты, цифры на главной.
class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key, required this.api});
  final SiteApi api;

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

const _fields = [
  ['name', 'Название магазина'],
  ['phone', 'Телефон (как показывать на сайте), например +998 90 123 45 67'],
  ['phoneRaw', 'Телефон для WhatsApp — только цифры, например 998901234567'],
  ['telegram', 'Telegram магазина (без @)'],
  ['address', 'Адрес'],
  ['hours', 'Часы работы'],
  ['mapUrl', 'Ссылка на карту'],
  ['years', 'Сколько лет продаёте плитку (на главной «20+»)'],
  ['clients', 'Довольных клиентов (на главной «100 000+»)'],
  ['usdRate', 'Курс: сколько сумов в 1 \$'],
  ['deliveryNote', 'Условия доставки (видно в корзине)'],
  ['payCard', 'Номер карты для перевода (на сайте не видно)'],
  ['payCardHolder', 'Владелец карты'],
  ['payBank', 'Банковский счёт / реквизиты'],
];

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final ctl = {for (final f in _fields) f[0]: TextEditingController()};
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.api.shopSettings().then((s) {
      for (final f in _fields) {
        ctl[f[0]]!.text = s[f[0]] == null ? '' : '${s[f[0]]}';
      }
      setState(() => loading = false);
    }).catchError((Object e) => setState(() { error = '$e'; loading = false; }));
  }

  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { saving = true; error = null; });
    try {
      await widget.api.saveShopSettings({for (final f in _fields) f[0]: ctl[f[0]]!.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено — уже на сайте')));
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          for (final f in _fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(controller: ctl[f[0]], maxLines: f[0] == 'payBank' || f[0] == 'deliveryNote' ? 3 : 1, minLines: 1,
                  decoration: InputDecoration(labelText: f[1], border: const OutlineInputBorder())),
            ),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          FilledButton(onPressed: saving ? null : _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Сохранить'))),
        ]),
      ),
    );
  }
}
