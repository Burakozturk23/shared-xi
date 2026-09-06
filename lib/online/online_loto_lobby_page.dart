import 'package:flutter/material.dart';

import '../services/auth_service.dart';

import 'room_service.dart';
import 'online_loto_setup_page.dart';

/// Loto için oda kur / koda katıl (mevcut RoomService API).
class OnlineLotoLobbyPage extends StatefulWidget {
  const OnlineLotoLobbyPage({super.key});

  @override
  State<OnlineLotoLobbyPage> createState() => _OnlineLotoLobbyPageState();
}

class _OnlineLotoLobbyPageState extends State<OnlineLotoLobbyPage> {
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
      final code = await RoomService.createRoom(
        playerName: name,
        matchType: 'loto',
        hostUid: AuthService.uid,
      );
      if (!mounted) return;
      setState(() => _isCreating = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineLotoSetupPage(
            roomCode: code,
            playerName: name,
            isHost: true,
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
      final ok = await RoomService.joinRoom(roomCode: code, playerName: name);
      if (!mounted) return;
      setState(() => _isJoining = false);
      if (!ok) {
        _msg('Odaya girilemedi.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineLotoSetupPage(
            roomCode: code,
            playerName: name,
            isHost: false,
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
      appBar: AppBar(title: const Text('Football Loto · Online')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Oda kur', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Oyuncu adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isCreating ? null : _createRoom,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Oda kur'),
          ),
          const SizedBox(height: 28),
          const Text('Koda katıl',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _joinNameController,
            decoration: const InputDecoration(
              labelText: 'Oyuncu adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Oda kodu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isJoining ? null : _joinRoom,
            child: _isJoining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Katıl'),
          ),
        ],
      ),
    );
  }
}
