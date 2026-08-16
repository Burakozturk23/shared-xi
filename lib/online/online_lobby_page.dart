import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../services/database_service.dart';
import '../online/room_service.dart';
import '../screens/game_page.dart';

class OnlineLobbyPage extends StatefulWidget {
  const OnlineLobbyPage({super.key});

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _joinNameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();

  String? _roomCode;
  String? _joinedRoomCode;
  String? _currentPlayerName;

  bool _isCreating = false;
  bool _isJoining = false;
  bool _isLoadingClubs = false;
  bool _gameStarting = false;

  List<Club> _clubs = [];
  List<Player> _players = [];
  int? _selectedTeamId;
  String _teamSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    setState(() {
      _isLoadingClubs = true;
    });

    try {
      final clubs = await DatabaseService.loadClubs();
      final players = await DatabaseService.loadPlayers();

      if (!mounted) return;

      setState(() {
        _clubs = clubs;
        _players = players;
        _isLoadingClubs = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingClubs = false;
      });

      _showMessage('Takımlar yüklenemedi: $e');
    }
  }

  Future<void> _createRoom() async {
    final playerName = _nameController.text.trim();

    if (playerName.isEmpty) {
      _showMessage('Lütfen oyuncu adını gir.');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final roomCode = await RoomService.createRoom(
        playerName: playerName,
      );

      if (!mounted) return;

      setState(() {
        _roomCode = roomCode;
        _joinedRoomCode = roomCode;
        _currentPlayerName = playerName;
        _selectedTeamId = null;
        _isCreating = false;
      });

      _showMessage('Oda oluşturuldu!');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      _showMessage('Oda oluşturulamadı: $e');
    }
  }

  Future<void> _joinRoom() async {
    final playerName = _joinNameController.text.trim();
    final roomCode = _roomCodeController.text.trim().toUpperCase();

    if (playerName.isEmpty) {
      _showMessage('Lütfen oyuncu adını gir.');
      return;
    }

    if (roomCode.isEmpty) {
      _showMessage('Lütfen oda kodunu gir.');
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final joined = await RoomService.joinRoom(
        roomCode: roomCode,
        playerName: playerName,
      );

      if (!mounted) return;

      if (!joined) {
        setState(() {
          _isJoining = false;
        });

        _showMessage(
          'Odaya katılamadın. Kod yanlış, oda dolu veya oyun başlamış olabilir.',
        );
        return;
      }

      setState(() {
        _joinedRoomCode = roomCode;
        _currentPlayerName = playerName;
        _selectedTeamId = null;
        _isJoining = false;
      });

      _showMessage('Odaya başarıyla katıldın!');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isJoining = false;
      });

      _showMessage('Bir hata oluştu: $e');
    }
  }

  bool _hasCommonPlayer(int team1Id, int team2Id) {
    if (team1Id == team2Id) {
      return false;
    }

    for (final player in _players) {
      if (player.clubs.contains(team1Id) &&
          player.clubs.contains(team2Id)) {
        return true;
      }
    }

    return false;
  }

  String _clubName(int teamId) {
    for (final club in _clubs) {
      if (club.id == teamId) {
        return club.name;
      }
    }
    return 'Bu takım';
  }

  List<Club> get _filteredClubs {
    final query = _teamSearchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _clubs;
    }

    return _clubs.where((club) {
      return club.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectTeam(int teamId) async {
    final roomCode = _joinedRoomCode;
    final playerName = _currentPlayerName;

    if (roomCode == null || playerName == null) {
      return;
    }

    final players = await _getPlayers();

    if (players != null) {
      for (final entry in players.entries) {
        if (entry.key == playerName) {
          continue;
        }

        final playerData = Map<String, dynamic>.from(
          entry.value as Map,
        );

        final otherTeamId = int.tryParse(
          playerData['teamId']?.toString() ?? '',
        );

        if (otherTeamId == null) {
          continue;
        }

        if (otherTeamId == teamId) {
          _showMessage('Bu takım diğer oyuncu tarafından seçildi.');
          return;
        }

        if (!_hasCommonPlayer(teamId, otherTeamId)) {
          _showMessage(
            '${_clubName(otherTeamId)} ile en az 1 ortak oyuncusu olan bir takım seçmelisin.',
          );
          return;
        }
      }
    }

    try {
      await RoomService.setPlayerTeam(
        roomCode: roomCode,
        playerName: playerName,
        teamId: teamId,
      );

      if (!mounted) return;

      setState(() {
        _selectedTeamId = teamId;
      });
    } catch (e) {
      _showMessage('Takım seçilemedi: $e');
    }
  }

  Future<Map<String, dynamic>?> _getPlayers() async {
    final roomCode = _joinedRoomCode;

    if (roomCode == null) {
      return null;
    }

    final room = await RoomService.getRoom(roomCode);

    if (room == null || room['players'] == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      room['players'] as Map,
    );
  }

  Future<void> _setReady() async {
    final roomCode = _joinedRoomCode;
    final playerName = _currentPlayerName;

    if (roomCode == null || playerName == null) {
      return;
    }

    if (_selectedTeamId == null) {
      _showMessage('Önce bir takım seçmelisin.');
      return;
    }

    try {
      final players = await _getPlayers();

      if (players == null || players.length != 2) {
        _showMessage('Oyunun başlaması için 2 oyuncu gerekli.');
        return;
      }

      int? otherTeamId;

      for (final entry in players.entries) {
        if (entry.key == playerName) {
          continue;
        }

        final playerData = Map<String, dynamic>.from(
          entry.value as Map,
        );

        otherTeamId = int.tryParse(
          playerData['teamId']?.toString() ?? '',
        );
        break;
      }

      if (otherTeamId == null) {
        _showMessage('Diğer oyuncunun takımını seçmesi bekleniyor.');
        return;
      }

      if (!_hasCommonPlayer(_selectedTeamId!, otherTeamId)) {
        _showMessage(
          'Seçtiğiniz takımlar arasında ortak oyuncu bulunmuyor.',
        );
        return;
      }

      await RoomService.setReady(
        roomCode: roomCode,
        playerName: playerName,
        ready: true,
      );

      await RoomService.startRoom(roomCode);
    } catch (e) {
      _showMessage('Hazır durumu değiştirilemedi: $e');
    }
  }

  Future<void> _openOnlineGame() async {
    if (_gameStarting) {
      return;
    }

    final roomCode = _joinedRoomCode;

    if (roomCode == null) {
      return;
    }

    setState(() {
      _gameStarting = true;
    });

    try {
      final room = await RoomService.getRoom(roomCode);

      if (room == null || room['players'] == null) {
        throw Exception('Oda veya oyuncu bilgileri bulunamadı.');
      }

      final players = Map<String, dynamic>.from(
        room['players'] as Map,
      );

      if (players.length != 2) {
        throw Exception('Oyunda tam olarak 2 oyuncu olmalı.');
      }

      final teamIds = <int>[];

      for (final entry in players.entries) {
        final playerData = Map<String, dynamic>.from(
          entry.value as Map,
        );

        final teamId = int.tryParse(
          playerData['teamId']?.toString() ?? '',
        );

        if (teamId == null) {
          throw Exception(
            '${entry.key} henüz takım seçmedi.',
          );
        }

        teamIds.add(teamId);
      }

      if (teamIds[0] == teamIds[1]) {
        throw Exception('İki oyuncu farklı takımlar seçmeli.');
      }

      Club? club1;
      Club? club2;

      for (final club in _clubs) {
        if (club.id == teamIds[0]) {
          club1 = club;
        }

        if (club.id == teamIds[1]) {
          club2 = club;
        }
      }

      if (club1 == null || club2 == null) {
        throw Exception('Seçilen takımlardan biri bulunamadı.');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePage(
            entity1: MatchEntity.club(club1!),
            entity2: MatchEntity.club(club2!),
            roomCode: roomCode,
            playerName: _currentPlayerName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _gameStarting = false;
      });

      _showMessage('Online oyun başlatılamadı: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTeamSelector() {
    if (_isLoadingClubs) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_clubs.isEmpty) {
      return const Text(
        'Takım listesi bulunamadı.',
        textAlign: TextAlign.center,
      );
    }

    final filteredClubs = _filteredClubs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _teamSearchQuery = value;
            });
          },
          decoration: InputDecoration(
            labelText: 'Takım ara',
            hintText: 'Örn. Fenerbahçe, Galatasaray...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _teamSearchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _teamSearchQuery = '';
                      });
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        if (filteredClubs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aradığın takım bulunamadı.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredClubs.length,
              itemBuilder: (context, index) {
                final club = filteredClubs[index];
                final isSelected = club.id == _selectedTeamId;

                return ListTile(
                  dense: true,
                  title: Text(
                    club.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle)
                      : null,
                  selected: isSelected,
                  onTap: _gameStarting
                      ? null
                      : () => _selectTeam(club.id),
                );
              },
            ),
          ),
        if (_selectedTeamId != null) ...[
          const SizedBox(height: 10),
          Text(
            'Seçilen takım: ${_clubName(_selectedTeamId!)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'İki takım arasında en az 1 ortak oyuncu bulunması gerekir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLobby() {
    final roomCode = _joinedRoomCode;

    if (roomCode == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<DatabaseEvent>(
          stream: RoomService.watchRoomStatus(roomCode),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final status = snapshot.data!.snapshot.value;

              if (status == 'starting' && !_gameStarting) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _openOnlineGame();
                });
              }
            }

            return const SizedBox.shrink();
          },
        ),

        const SizedBox(height: 30),

        Text(
          'Oda: $roomCode',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Önce kendi takımını seç.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17),
        ),

        const SizedBox(height: 15),

        _buildTeamSelector(),

        const SizedBox(height: 25),

        StreamBuilder<DatabaseEvent>(
          stream: RoomService.watchPlayers(roomCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'Oyuncular alınamadı:\n${snapshot.error}',
                textAlign: TextAlign.center,
              );
            }

            final value = snapshot.data?.snapshot.value;

            if (value == null) {
              return const Text(
                'Henüz oyuncu yok.',
                textAlign: TextAlign.center,
              );
            }

            final data = Map<String, dynamic>.from(
              value as Map,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Oyuncular',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                ...data.entries.map((entry) {
                  final playerName = entry.key;

                  final playerData =
                      Map<String, dynamic>.from(
                    entry.value as Map,
                  );

                  final teamId = int.tryParse(
                    playerData['teamId']?.toString() ?? '',
                  );

                  Club? selectedClub;

                  if (teamId != null) {
                    for (final club in _clubs) {
                      if (club.id == teamId) {
                        selectedClub = club;
                        break;
                      }
                    }
                  }

                  final isReady =
                      playerData['ready'] == true;

                  final isMe =
                      playerName == _currentPlayerName;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(
                        '$playerName${isMe ? ' (Sen)' : ''}',
                      ),
                      subtitle: Text(
                        selectedClub == null
                            ? 'Takım seçmedi'
                            : '${selectedClub.name} • ${isReady ? 'Hazır' : 'Hazır değil'}',
                      ),
                      trailing: Icon(
                        isReady
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _selectedTeamId == null ||
                          _gameStarting
                      ? null
                      : _setReady,
                  child: Text(
                    _gameStarting
                        ? 'OYUN BAŞLIYOR...'
                        : 'HAZIR',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Oyun'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Online Oyun',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Oda Oluştur',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Oyuncu adı',
                  hintText: 'Örneğin: Burak',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isCreating ? null : _createRoom,
                child: _isCreating
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('ODA OLUŞTUR'),
              ),

              if (_roomCode != null) ...[
                const SizedBox(height: 25),

                const Text(
                  'Oda Kodun',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _roomCode!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 45),

              const Divider(),

              const SizedBox(height: 30),

              const Text(
                'Mevcut Odaya Katıl',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _joinNameController,
                decoration: const InputDecoration(
                  labelText: 'Oyuncu adı',
                  hintText: 'Örneğin: Ahmet',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _roomCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Oda kodu',
                  hintText: 'Örneğin: K7X9P2',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isJoining ? null : _joinRoom,
                child: _isJoining
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('ODAYA KATIL'),
              ),

              if (_joinedRoomCode != null) ...[
                _buildLobby(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _joinNameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }
}
