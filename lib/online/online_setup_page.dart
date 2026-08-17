import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import 'room_service.dart';
import '../repositories/repository.dart';
import '../screens/game_page.dart';
import '../services/database_service.dart';

/// Takım seçimi + hazır. Rakibin takımı GÖRÜNMEZ.
class OnlineSetupPage extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const OnlineSetupPage({
    super.key,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<OnlineSetupPage> createState() => _OnlineSetupPageState();
}

class _OnlineSetupPageState extends State<OnlineSetupPage> {
  List<Club> _clubs = [];
  List<Player> _players = [];
  bool _loading = true;
  int? _selectedTeamId;
  String _search = '';
  bool _gameStarting = false;
  bool _iAmReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clubs = List<Club>.from(Repository.instance.clubs);
      final players = List<Player>.from(Repository.instance.players);
      setState(() {
        _clubs = clubs;
        _players = players;
        _loading = false;
      });
    } catch (_) {
      try {
        final clubs = await DatabaseService.loadClubs();
        final players = await DatabaseService.loadPlayers();
        if (!mounted) return;
        setState(() {
          _clubs = clubs;
          _players = players;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        _msg('Veri yüklenemedi: $e');
      }
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  bool _hasCommon(int a, int b) {
    if (a == b) return false;
    for (final p in _players) {
      if (p.clubs.contains(a) && p.clubs.contains(b)) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _playersMap() async {
    final room = await RoomService.getRoom(widget.roomCode);
    if (room == null || room['players'] is! Map) return null;
    return Map<String, dynamic>.from(room['players'] as Map);
  }

  Future<void> _selectTeam(int teamId) async {
    final players = await _playersMap();
    if (players != null) {
      for (final e in players.entries) {
        if (e.key == widget.playerName) continue;
        final data = Map<String, dynamic>.from(e.value as Map);
        final otherId = int.tryParse(data['teamId']?.toString() ?? '');
        if (otherId == null) continue;
        if (otherId == teamId) {
          _msg('Bu takım dolu (rakip seçmiş olabilir). Başka takım dene.');
          return;
        }
        if (!_hasCommon(teamId, otherId)) {
          _msg(
            'Bu takımın rakibin seçimiyle ortak oyuncusu yok. Başka takım seç.',
          );
          return;
        }
      }
    }

    try {
      await RoomService.setPlayerTeam(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        teamId: teamId,
      );
      if (!mounted) return;
      setState(() {
        _selectedTeamId = teamId;
        _iAmReady = false;
      });
    } catch (e) {
      _msg('Takım seçilemedi: $e');
    }
  }

  Future<void> _setReady() async {
    if (_selectedTeamId == null) {
      _msg('Önce takım seç.');
      return;
    }

    final players = await _playersMap();
    if (players == null || players.length < 2) {
      _msg('2 oyuncu gerekli.');
      return;
    }

    int? otherTeamId;
    for (final e in players.entries) {
      if (e.key == widget.playerName) continue;
      final data = Map<String, dynamic>.from(e.value as Map);
      otherTeamId = int.tryParse(data['teamId']?.toString() ?? '');
      break;
    }

    if (otherTeamId == null) {
      _msg('Rakip henüz takım seçmedi.');
      return;
    }

    if (!_hasCommon(_selectedTeamId!, otherTeamId)) {
      _msg('Takımlarınız arasında ortak oyuncu yok. Takım değiştir.');
      return;
    }

    try {
      await RoomService.setReady(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        ready: true,
      );
      setState(() => _iAmReady = true);
      await RoomService.startRoom(widget.roomCode);
    } catch (e) {
      _msg('Hazır olunamadı: $e');
    }
  }

  Future<void> _openGame() async {
    if (_gameStarting) return;
    setState(() => _gameStarting = true);

    try {
      final room = await RoomService.getRoom(widget.roomCode);
      if (room == null || room['players'] is! Map) {
        throw Exception('Oda bulunamadı');
      }
      final players = Map<String, dynamic>.from(room['players'] as Map);
      if (players.length != 2) throw Exception('2 oyuncu gerekli');

      final teamIds = <int>[];
      for (final e in players.entries) {
        final data = Map<String, dynamic>.from(e.value as Map);
        final tid = int.tryParse(data['teamId']?.toString() ?? '');
        if (tid == null) throw Exception('Takım seçimleri eksik');
        teamIds.add(tid);
      }
      if (teamIds[0] == teamIds[1]) {
        throw Exception('Aynı takım seçilemez');
      }

      Club? c1;
      Club? c2;
      for (final c in _clubs) {
        if (c.id == teamIds[0]) c1 = c;
        if (c.id == teamIds[1]) c2 = c;
      }
      if (c1 == null || c2 == null) throw Exception('Takım bulunamadı');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePage(
            entity1: MatchEntity.club(c1!),
            entity2: MatchEntity.club(c2!),
            roomCode: widget.roomCode,
            playerName: widget.playerName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gameStarting = false);
      _msg('Oyun açılamadı: $e');
    }
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

  List<Club> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _clubs;
    return _clubs.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hazırlık • ${widget.roomCode}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leave,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status stream — rakip takım ADI gösterilmez
                StreamBuilder<DatabaseEvent>(
                  stream: RoomService.watchRoomStatus(widget.roomCode),
                  builder: (context, snap) {
                    final status = snap.data?.snapshot.value;
                    if (status == 'starting' && !_gameStarting) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _openGame();
                      });
                    }
                    return const SizedBox.shrink();
                  },
                ),
                StreamBuilder<DatabaseEvent>(
                  stream: RoomService.watchPlayers(widget.roomCode),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data!.snapshot.value is! Map) {
                      return const Text('Oyuncular yükleniyor…');
                    }
                    final data = Map<String, dynamic>.from(
                      snap.data!.snapshot.value as Map,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Oyuncular',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...data.entries.map((e) {
                          final name = e.key;
                          final pdata =
                              Map<String, dynamic>.from(e.value as Map);
                          final isMe = name == widget.playerName;
                          final hasTeam = pdata['teamId'] != null;
                          final ready = pdata['ready'] == true;

                          // Kendi takımını göster, rakibinkini gizle
                          String subtitle;
                          if (isMe) {
                            final tid = int.tryParse(
                              pdata['teamId']?.toString() ?? '',
                            );
                            String teamName = 'Takım seçilmedi';
                            if (tid != null) {
                              for (final c in _clubs) {
                                if (c.id == tid) {
                                  teamName = c.name;
                                  break;
                                }
                              }
                            }
                            subtitle =
                                '$teamName • ${ready ? 'Hazır' : 'Hazır değil'}';
                          } else {
                            subtitle = hasTeam
                                ? (ready
                                    ? 'Takım seçti • Hazır'
                                    : 'Takım seçti • Hazır değil')
                                : 'Takım seçmedi';
                          }

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isMe ? Icons.person : Icons.person_outline,
                              ),
                              title: Text('$name${isMe ? ' (Sen)' : ''}'),
                              subtitle: Text(subtitle),
                              trailing: Icon(
                                ready
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: ready ? Colors.green : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Takımını seç (rakip görmez)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    labelText: 'Takım ara',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final club = _filtered[i];
                      final sel = club.id == _selectedTeamId;
                      return ListTile(
                        dense: true,
                        title: Text(club.name),
                        trailing: sel ? const Icon(Icons.check_circle) : null,
                        selected: sel,
                        onTap: _gameStarting || _iAmReady
                            ? null
                            : () => _selectTeam(club.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rakibin takımı gizli tutulur. İkiniz de hazır olunca maç başlar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_selectedTeamId == null ||
                          _gameStarting ||
                          _iAmReady)
                      ? null
                      : _setReady,
                  child: Text(
                    _gameStarting
                        ? 'OYUN BAŞLIYOR…'
                        : _iAmReady
                            ? 'HAZIR — rakip bekleniyor'
                            : 'HAZIRIM',
                  ),
                ),
              ],
            ),
    );
  }
}
