import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../screens/game_page.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import 'online_mode_catalog.dart';
import 'room_service.dart';

/// Takım / ülke seçimi + hazır. Rakibin seçimi GÖRÜNMEZ.
class OnlineSetupPage extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final OnlinePlayMode mode;

  const OnlineSetupPage({
    super.key,
    required this.roomCode,
    required this.playerName,
    this.mode = OnlinePlayMode.sharedXi,
  });

  @override
  State<OnlineSetupPage> createState() => _OnlineSetupPageState();
}

class _OnlineSetupPageState extends State<OnlineSetupPage> {
  List<Club> _clubs = [];
  List<String> _countries = [];
  bool _loading = true;
  int? _selectedTeamId;
  String? _selectedCountry;

  /// club | country  (clubCountry modunda)
  String _pickSide = 'club';
  String _search = '';
  bool _gameStarting = false;
  bool _iAmReady = false;

  bool get _isClubCountry => widget.mode == OnlinePlayMode.clubCountry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final query = GameDataV4QueryService.instance;
      final results = await Future.wait<Object>([
        query.allClubs(),
        query.countries(),
      ]);

      if (!mounted) return;
      _applyData(results[0] as List<Club>, results[1] as List<String>);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _msg('Veri yüklenemedi: $e');
    }
  }

  void _applyData(List<Club> clubs, List<String> countries) {
    setState(() {
      _clubs = clubs;
      _countries = countries;
      _loading = false;
    });
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _hasClubClubCommon(int a, int b) async {
    if (a == b) return false;
    return GameDataV4QueryService.instance.hasClubClubMatch(a, b);
  }

  Future<bool> _hasClubCountryCommon(int clubId, String country) {
    return GameDataV4QueryService.instance.hasClubCountryMatch(clubId, country);
  }

  Future<Map<String, dynamic>?> _playersMap() async {
    final room = await RoomService.getRoom(widget.roomCode);
    if (room == null || room['players'] is! Map) return null;
    return Map<String, dynamic>.from(room['players'] as Map);
  }

  Future<void> _selectClub(int teamId) async {
    final players = await _playersMap();
    if (players != null) {
      for (final e in players.entries) {
        if (e.key == widget.playerName) continue;
        final data = Map<String, dynamic>.from(e.value as Map);
        if (_isClubCountry) {
          final otherType = data['pickType']?.toString();
          if (otherType == 'club') {
            _msg('Rakip de kulüp seçmiş. Sen ülke seçmelisin.');
            return;
          }
          final otherCountry = data['countryName']?.toString();
          if (otherCountry != null &&
              otherCountry.isNotEmpty &&
              !await _hasClubCountryCommon(teamId, otherCountry)) {
            _msg('Bu kulübün rakibin ülkesiyle ortak oyuncusu yok.');
            return;
          }
        } else {
          final otherId = int.tryParse(data['teamId']?.toString() ?? '');
          if (otherId == null) continue;
          if (otherId == teamId) {
            _msg('Bu takım dolu. Başka takım dene.');
            return;
          }
          if (!await _hasClubClubCommon(teamId, otherId)) {
            _msg('Bu takımın rakibin seçimiyle ortak oyuncusu yok.');
            return;
          }
        }
      }
    }

    try {
      if (_isClubCountry) {
        await RoomService.setPlayerPick(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
          pickType: 'club',
          teamId: teamId,
          countryName: null,
        );
      } else {
        await RoomService.setPlayerTeam(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
          teamId: teamId,
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedTeamId = teamId;
        _selectedCountry = null;
        _pickSide = 'club';
        _iAmReady = false;
      });
    } catch (e) {
      _msg('Seçilemedi: $e');
    }
  }

  Future<void> _selectCountry(String country) async {
    final players = await _playersMap();
    if (players != null) {
      for (final e in players.entries) {
        if (e.key == widget.playerName) continue;
        final data = Map<String, dynamic>.from(e.value as Map);
        final otherType = data['pickType']?.toString();
        if (otherType == 'country') {
          _msg('Rakip de ülke seçmiş. Sen kulüp seçmelisin.');
          return;
        }
        final otherClub = int.tryParse(data['teamId']?.toString() ?? '');
        if (otherClub != null &&
            !await _hasClubCountryCommon(otherClub, country)) {
          _msg('Bu ülkenin rakibin kulübüyle ortak oyuncusu yok.');
          return;
        }
      }
    }

    try {
      await RoomService.setPlayerPick(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        pickType: 'country',
        teamId: null,
        countryName: country,
      );
      if (!mounted) return;
      setState(() {
        _selectedCountry = country;
        _selectedTeamId = null;
        _pickSide = 'country';
        _iAmReady = false;
      });
    } catch (e) {
      _msg('Seçilemedi: $e');
    }
  }

  Future<void> _setReady() async {
    if (_isClubCountry) {
      if (_selectedTeamId == null &&
          (_selectedCountry == null || _selectedCountry!.isEmpty)) {
        _msg('Önce kulüp veya ülke seç.');
        return;
      }
    } else if (_selectedTeamId == null) {
      _msg('Önce takım seç.');
      return;
    }

    final players = await _playersMap();
    if (players == null || players.length < 2) {
      _msg('2 oyuncu gerekli.');
      return;
    }

    Map<String, dynamic>? other;
    for (final e in players.entries) {
      if (e.key == widget.playerName) continue;
      other = Map<String, dynamic>.from(e.value as Map);
      break;
    }
    if (other == null) {
      _msg('Rakip bulunamadı.');
      return;
    }

    if (_isClubCountry) {
      final myClub = _selectedTeamId;
      final myCountry = _selectedCountry;
      final oType = other['pickType']?.toString();
      final oClub = int.tryParse(other['teamId']?.toString() ?? '');
      final oCountry = other['countryName']?.toString();

      if (myClub != null) {
        if (oType != 'country' || oCountry == null || oCountry.isEmpty) {
          _msg('Rakip henüz ülke seçmedi.');
          return;
        }
        if (!await _hasClubCountryCommon(myClub, oCountry)) {
          _msg('Kesişimde ortak oyuncu yok. Seçimi değiştir.');
          return;
        }
      } else if (myCountry != null) {
        if (oType != 'club' || oClub == null) {
          _msg('Rakip henüz kulüp seçmedi.');
          return;
        }
        if (!await _hasClubCountryCommon(oClub, myCountry)) {
          _msg('Kesişimde ortak oyuncu yok. Seçimi değiştir.');
          return;
        }
      }
    } else {
      final otherTeamId = int.tryParse(other['teamId']?.toString() ?? '');
      if (otherTeamId == null) {
        _msg('Rakip henüz takım seçmedi.');
        return;
      }
      if (!await _hasClubClubCommon(_selectedTeamId!, otherTeamId)) {
        _msg('Takımlarınız arasında ortak oyuncu yok.');
        return;
      }
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

      MatchEntity e1;
      MatchEntity e2;

      if (_isClubCountry) {
        int? clubId;
        String? country;
        for (final e in players.entries) {
          final data = Map<String, dynamic>.from(e.value as Map);
          final t = data['pickType']?.toString();
          if (t == 'club') {
            clubId = int.tryParse(data['teamId']?.toString() ?? '');
          } else if (t == 'country') {
            country = data['countryName']?.toString();
          }
        }
        if (clubId == null || country == null || country.isEmpty) {
          throw Exception('Kulüp / ülke seçimleri eksik');
        }
        Club? club;
        for (final c in _clubs) {
          if (c.id == clubId) club = c;
        }
        if (club == null) throw Exception('Kulüp bulunamadı');
        e1 = MatchEntity.club(club);
        e2 = MatchEntity.country(country);
      } else {
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
        e1 = MatchEntity.club(c1);
        e2 = MatchEntity.club(c2);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePage(
            entity1: e1,
            entity2: e2,
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

  List<Club> get _filteredClubs {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _clubs;
    return _clubs.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  List<String> get _filteredCountries {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _countries;
    return _countries.where((c) => c.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hazırlık · ${widget.mode.title}'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _leave),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                          final pdata = Map<String, dynamic>.from(
                            e.value as Map,
                          );
                          final isMe = name == widget.playerName;
                          final ready = pdata['ready'] == true;
                          final hasPick = _isClubCountry
                              ? (pdata['pickType'] != null)
                              : pdata['teamId'] != null;

                          String subtitle;
                          if (isMe) {
                            if (_isClubCountry) {
                              final t = pdata['pickType']?.toString();
                              if (t == 'club') {
                                final tid = int.tryParse(
                                  pdata['teamId']?.toString() ?? '',
                                );
                                String teamName = 'Kulüp';
                                if (tid != null) {
                                  for (final c in _clubs) {
                                    if (c.id == tid) {
                                      teamName = c.name;
                                      break;
                                    }
                                  }
                                }
                                subtitle =
                                    'Kulüp: $teamName · ${ready ? 'Hazır' : 'Hazır değil'}';
                              } else if (t == 'country') {
                                subtitle =
                                    'Ülke: ${pdata['countryName'] ?? '—'} · ${ready ? 'Hazır' : 'Hazır değil'}';
                              } else {
                                subtitle = 'Seçim yok';
                              }
                            } else {
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
                                  '$teamName · ${ready ? 'Hazır' : 'Hazır değil'}';
                            }
                          } else {
                            subtitle = hasPick
                                ? (ready
                                      ? 'Seçti · Hazır'
                                      : 'Seçti · Hazır değil')
                                : 'Seçmedi';
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
                if (_isClubCountry) ...[
                  const Text(
                    'Sen ne seçeceksin?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'club', label: Text('Kulüp')),
                      ButtonSegment(value: 'country', label: Text('Ülke')),
                    ],
                    selected: {_pickSide},
                    onSelectionChanged: _gameStarting || _iAmReady
                        ? null
                        : (s) {
                            setState(() {
                              _pickSide = s.first;
                              _search = '';
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                ] else
                  const Text(
                    'Takımını seç (rakip görmez)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    labelText: _isClubCountry && _pickSide == 'country'
                        ? 'Ülke ara'
                        : 'Takım ara',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isClubCountry && _pickSide == 'country'
                      ? ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredCountries.length,
                          itemBuilder: (_, i) {
                            final country = _filteredCountries[i];
                            final sel = country == _selectedCountry;
                            return ListTile(
                              dense: true,
                              title: Text(country),
                              trailing: sel
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              selected: sel,
                              onTap: _gameStarting || _iAmReady
                                  ? null
                                  : () => _selectCountry(country),
                            );
                          },
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredClubs.length,
                          itemBuilder: (_, i) {
                            final club = _filteredClubs[i];
                            final sel = club.id == _selectedTeamId;
                            return ListTile(
                              dense: true,
                              title: Text(club.name),
                              trailing: sel
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              selected: sel,
                              onTap: _gameStarting || _iAmReady
                                  ? null
                                  : () => _selectClub(club.id),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isClubCountry
                      ? 'Biri kulüp, diğeri ülke seçmeli. Ortak oyuncu zorunlu.'
                      : 'Rakibin takımı gizli tutulur. İkiniz de hazır olunca maç başlar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _gameStarting || _iAmReady ? null : _setReady,
                  child: Text(_iAmReady ? 'Hazırsın…' : 'HAZIR'),
                ),
              ],
            ),
    );
  }
}
