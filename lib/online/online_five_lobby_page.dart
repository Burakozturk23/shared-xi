import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/online_five_service.dart';
import 'online_five_page.dart';

class OnlineFiveLobbyPage extends StatefulWidget {
  const OnlineFiveLobbyPage({super.key});

  @override
  State<OnlineFiveLobbyPage> createState() => _OnlineFiveLobbyPageState();
}

class _OnlineFiveLobbyPageState extends State<OnlineFiveLobbyPage> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = AuthService.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthService.ensureSignedIn(
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      final id = await OnlineFiveService.createMatch(
        hostUid: user.uid,
        hostName: user.displayName ?? 'Oyuncu',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineFivePage(
            matchId: id,
            myUid: user.uid,
            myName: user.displayName ?? 'Oyuncu',
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Kod gir.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthService.ensureSignedIn(
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      final ok = await OnlineFiveService.joinMatch(
        matchId: code,
        uid: user.uid,
        displayName: user.displayName ?? 'Oyuncu',
      );
      if (!ok) {
        setState(() => _error = 'Odaya girilemedi.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineFivePage(
            matchId: code,
            myUid: user.uid,
            myName: user.displayName ?? 'Oyuncu',
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Rastgele Beş')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '5 kulüp · 90 sn · aynı anda tahmin\n'
              'Oyuncu kaç kulübe uyuyorsa o kadar puan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Görünen ad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _create,
              child: const Text('Oda kur'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Oda kodu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _join,
              child: const Text('Odaya katıl'),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
