import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'room_service.dart';
import 'online_setup_page.dart';

/// Host: oda kodu + 2. oyuncu bekleniyor.
/// 2 kişi olunca setup sayfasına geçer.
class OnlineWaitingPage extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const OnlineWaitingPage({
    super.key,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<OnlineWaitingPage> createState() => _OnlineWaitingPageState();
}

class _OnlineWaitingPageState extends State<OnlineWaitingPage> {
  StreamSubscription<DatabaseEvent>? _playersSub;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _playersSub = RoomService.watchPlayers(widget.roomCode).listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) return;
      if (value.length >= 2 && !_navigated) {
        _goSetup();
      }
      if (mounted) setState(() {});
    });
  }

  void _goSetup() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineSetupPage(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  Future<void> _leave() async {
    await RoomService.leaveRoom(
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      deleteRoomIfEmpty: true,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oda bekleniyor'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leave,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Oda kodunu arkadaşınla paylaş',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    widget.roomCode,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.roomCode),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kod kopyalandı')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Kodu kopyala'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            const Text(
              '2. oyuncu katılınca takım seçimine geçilecek…',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _leave,
              child: const Text('Odayı iptal et'),
            ),
          ],
        ),
      ),
    );
  }
}
