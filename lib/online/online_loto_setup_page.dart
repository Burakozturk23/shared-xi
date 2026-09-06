import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/loto_models.dart';
import '../screens/loto_online_page.dart';
import '../services/loto_generator.dart';
import 'room_service.dart';
import 'online_mode_catalog.dart';
import '../widgets/friend_match_invite_button.dart';

class OnlineLotoSetupPage extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const OnlineLotoSetupPage({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.isHost,
  });

  @override
  State<OnlineLotoSetupPage> createState() => _OnlineLotoSetupPageState();
}

class _OnlineLotoSetupPageState extends State<OnlineLotoSetupPage> {
  String? _league;
  LotoDifficulty _diff = LotoDifficulty.medium;
  bool _starting = false;
  StreamSubscription<DatabaseEvent>? _statusSub;

  DatabaseReference get _gameRef => FirebaseDatabase.instance
      .ref('rooms')
      .child(widget.roomCode.trim().toUpperCase())
      .child('game');

  @override
  void initState() {
    super.initState();
    if (!widget.isHost) {
      _statusSub = _gameRef.child('status').onValue.listen((e) {
        if (e.snapshot.value == 'playing' && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LotoOnlinePage(
                roomCode: widget.roomCode,
                playerName: widget.playerName,
                isHost: false,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_league == null || _starting) return;
    setState(() => _starting = true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LotoOnlinePage(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
          isHost: true,
          league: _league,
          difficulty: _diff,
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
  Widget build(BuildContext context) {
    if (!widget.isHost) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Oda ${widget.roomCode}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _leave,
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Host lig ve zorluk seçiyor…'),
            ],
          ),
        ),
      );
    }

    final leagues = LotoGenerator.availableLeagues();
    return Scaffold(
      appBar: AppBar(
        title: Text('Loto · ${widget.roomCode}'),
        actions: [
          FriendMatchInviteButton(
            mode: OnlinePlayMode.loto,
            roomCode: widget.roomCode,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leave,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Lig seç',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final L in leagues)
                ChoiceChip(
                  label: Text(L),
                  selected: _league == L,
                  onSelected: (_) => setState(() => _league = L),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Zorluk',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          for (final d in LotoDifficulty.values)
            RadioListTile<LotoDifficulty>(
              value: d,
              groupValue: _diff,
              onChanged: (v) => setState(() => _diff = v!),
              title: Text(d.label),
              subtitle: Text('${d.secondsPerPlayer}s · ${d.description}'),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _league == null || _starting ? null : _start,
            child: const Text('Maçı Başlat (3 dk)'),
          ),
        ],
      ),
    );
  }
}
