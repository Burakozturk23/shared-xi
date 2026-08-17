import 'package:flutter/material.dart';

import 'room_service.dart';
import 'online_setup_page.dart';
import 'online_waiting_page.dart';

/// Sadece oda oluştur / katıl. Takım seçimi ayrı sayfada.
class OnlineLobbyPage extends StatefulWidget {
  const OnlineLobbyPage({super.key});

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  final _nameController = TextEditingController();
  final _joinNameController = TextEditingController();
  final _roomCodeController = TextEditingController();

  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _nameController.dispose();
    _joinNameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _msg('Oyuncu adını gir.');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final code = await RoomService.createRoom(playerName: name);
      if (!mounted) return;
      setState(() => _isCreating = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineWaitingPage(
            roomCode: code,
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _msg('Oda oluşturulamadı: $e');
    }
  }

  Future<void> _joinRoom() async {
    final name = _joinNameController.text.trim();
    final code = _roomCodeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      _msg('Oyuncu adını gir.');
      return;
    }
    if (code.isEmpty) {
      _msg('Oda kodunu gir.');
      return;
    }

    setState(() => _isJoining = true);
    try {
      final ok = await RoomService.joinRoom(
        roomCode: code,
        playerName: name,
      );
      if (!mounted) return;
      setState(() => _isJoining = false);

      if (!ok) {
        _msg('Katılınamadı. Kod yanlış, oda dolu veya oyun başlamış olabilir.');
        return;
      }

      // 2. oyuncu → direkt hazırlık sayfası
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineSetupPage(
            roomCode: code,
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      _msg('Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşlarınla Oyna')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Oda oluştur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Adın',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createRoom(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isCreating ? null : _createRoom,
            child: Text(_isCreating ? 'Oluşturuluyor…' : 'Oda oluştur'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Odaya katıl',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _joinNameController,
            decoration: const InputDecoration(
              labelText: 'Adın',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCodeController,
            decoration: const InputDecoration(
              labelText: 'Oda kodu',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _joinRoom(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isJoining ? null : _joinRoom,
            child: Text(_isJoining ? 'Katılınıyor…' : 'Katıl'),
          ),
          const SizedBox(height: 24),
          const Text(
            '2 kişi olunca takım seçimi açılır. Rakibin takımı gizli kalır. Süre: 90 sn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
