import 'package:flutter/material.dart';

import '../../main.dart' show kDark2, kGold, kLight;
import '../../services/site_api.dart';
import '../settings_screen.dart';

/// Показывает [child] только после входа паролем админки сайта.
class LoginGate extends StatefulWidget {
  const LoginGate({super.key, required this.api, required this.child});
  final SiteApi api;
  final Widget child;

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool? ok;
  String? error;
  bool busy = false;
  final pw = TextEditingController();

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    pw.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => error = null);
    try {
      final r = await widget.api.checkSession();
      if (mounted) setState(() => ok = r);
    } catch (e) {
      if (mounted) setState(() { ok = false; error = '$e'; });
    }
  }

  Future<void> _login() async {
    setState(() { busy = true; error = null; });
    try {
      await widget.api.login(pw.text);
      pw.clear();
      if (mounted) setState(() => ok = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ok == true) return widget.child;
    if (ok == null) return const Center(child: CircularProgressIndicator());
    final s = widget.api.settings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          color: kDark2,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.lock_outline, color: kGold, size: 40),
              const SizedBox(height: 12),
              const Text('Вход в админку сайта', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kLight)),
              const SizedBox(height: 6),
              Text(s.usesServer ? s.serverUrl : 'Сначала впишите адрес сайта в настройках',
                  textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB5AC9F))),
              const SizedBox(height: 20),
              if (s.usesServer) ...[
                TextField(
                  controller: pw,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 14),
                FilledButton(onPressed: busy ? null : _login, child: const Padding(padding: EdgeInsets.all(12), child: Text('Войти'))),
              ] else
                FilledButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: s)));
                    _check();
                  },
                  child: const Padding(padding: EdgeInsets.all(12), child: Text('Открыть настройки')),
                ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                if (s.usesServer) TextButton(onPressed: _check, child: const Text('Повторить')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
