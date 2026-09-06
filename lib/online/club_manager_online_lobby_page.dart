import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/manager_rating.dart';
import '../services/auth_service.dart';
import 'club_manager_online_service.dart';
import 'club_manager_online_squad_page.dart';

class ClubManagerOnlineLobbyPage extends StatefulWidget {
  const ClubManagerOnlineLobbyPage({super.key});

  @override
  State<ClubManagerOnlineLobbyPage> createState() =>
      _ClubManagerOnlineLobbyPageState();
}

class _ClubManagerOnlineLobbyPageState extends State<ClubManagerOnlineLobbyPage> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  ManagerDifficulty _diff = ManagerDifficulty.medium;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  int get _budget => _diff.budgetLink;

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'İsim gir');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await ClubManagerOnlineService.instance.createRoom(
        playerName: name,
        budgetLink: _budget,
        hostUid: AuthService.uid,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClubManagerOnlineSquadPage(
            roomCode: code,
            playerName: name,
            isHost: true,
            budgetLink: _budget,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      setState(() => _error = 'İsim ve oda kodu gerekli');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ClubManagerOnlineService.instance.joinRoom(
        roomCode: code,
        playerName: name,
      );
      if (!ok) {
        setState(() => _error = 'Odaya girilemedi (dolu / yanlış kod / mod)');
        return;
      }
      final cm = await ClubManagerOnlineService.instance.loadClubManager(code);
      final budget = (cm?['budgetLink'] as num?)?.toInt() ?? _budget;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClubManagerOnlineSquadPage(
            roomCode: code,
            playerName: name,
            isHost: false,
            budgetLink: budget,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Club Manager · Online',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Kafa kafaya',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aynı bütçe · 11 kur · ikiniz de hazır olunca simülasyon.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Görünen ad',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Bütçe (oda kurarken)',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ManagerDifficulty.values.map((d) {
              final sel = d == _diff;
              return ChoiceChip(
                label: Text('${d.label} ${d.budgetLink}'),
                selected: sel,
                onSelected: (_) => setState(() => _diff = d),
                selectedColor: const Color(0xFF00E676),
                labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.w700),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _busy ? null : _create,
            child: Text(_busy ? '...' : 'ODA KUR',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 28),
          const Text('Koda katıl',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white, letterSpacing: 3),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Oda kodu',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            child: const Text('KATIL'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}
