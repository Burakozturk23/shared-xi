import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/grid_sub_type.dart';
import '../services/auth_service.dart';
import '../services/online_grid_service.dart';
import 'online_grid_page.dart';

class OnlineGridLobbyPage extends StatefulWidget {
  final GridSubType? initialSubType;

  const OnlineGridLobbyPage({super.key, this.initialSubType});

  @override
  State<OnlineGridLobbyPage> createState() => _OnlineGridLobbyPageState();
}

class _OnlineGridLobbyPageState extends State<OnlineGridLobbyPage> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  late GridSubType _subType;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subType = widget.initialSubType ?? GridSubType.classic;
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
      final id = await OnlineGridService.createMatch(
        hostUid: user.uid,
        hostName: user.displayName ?? 'Oyuncu',
        subType: _subType,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGridPage(
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
      final ok = await OnlineGridService.joinMatch(
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
          builder: (_) => OnlineGridPage(
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
      appBar: AppBar(title: const Text('Online Grid')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Mod seç', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final t in GridSubType.values) ...[
            RadioListTile<GridSubType>(
              value: t,
              groupValue: _subType,
              title: Text(t.titleTr),
              subtitle: Text(t.subtitleTr, style: const TextStyle(fontSize: 12)),
              onChanged: (v) {
                if (v != null) setState(() => _subType = v);
              },
            ),
          ],
          const SizedBox(height: 12),
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
            child: Text('${_subType.titleTr} odası kur'),
          ),
          const SizedBox(height: 24),
          const Text('veya odaya katıl (mod host’tan gelir)'),
          const SizedBox(height: 8),
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
    );
  }
}
