import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/build_xi_formations.dart';
import '../data/famous_coaches_seed.dart';
import '../models/coach.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class CoachXiController extends ChangeNotifier {
  CoachXiController();

  final _rng = Random();

  Formation formation = formation433;
  bool isLoading = true;
  String? errorMessage;

  /// Rulet için aday listesi (havuzu yeterli olanlar)
  List<Coach> candidates = [];
  Coach? coach;
  List<Player> pool = [];
  List<Player?> slots = [];
  int? selectedSlot;
  String searchQuery = '';
  List<Player> searchResults = [];

  bool spinning = false;

  int get filledCount => slots.where((p) => p != null).length;
  int get totalSlots => formation.slots.length;
  bool get isComplete => filledCount == totalSlots;

  void initialize() {
    formation = formation433;
    slots = List<Player?>.filled(formation.slots.length, null);
    selectedSlot = null;
    _buildCandidates();
    isLoading = false;
    notifyListeners();
  }

  List<Coach> _allCoaches() {
    final byKey = <String, Coach>{};
    for (final c in famousCoachesSeed) {
      byKey[c.name.toLowerCase()] = c;
    }
    for (final c in Repository.instance.coaches) {
      if (c.clubIds.isEmpty) continue;
      final key = c.name.toLowerCase();
      final prev = byKey[key];
      if (prev != null) {
        byKey[key] = Coach(
          id: c.id,
          name: c.name,
          countries: c.countries.isNotEmpty ? c.countries : prev.countries,
          clubIds: {...prev.clubIds, ...c.clubIds}.toList(),
          aliases: {...prev.aliases, ...c.aliases}.toList(),
          avatarKey: c.avatarKey ?? prev.avatarKey,
          rating: c.rating ?? prev.rating,
        );
      } else {
        byKey[key] = c;
      }
    }
    return byKey.values.toList();
  }

  void _buildCandidates() {
    errorMessage = null;
    candidates = [];
    final coaches = _allCoaches();
    for (final c in coaches) {
      if (c.clubIds.isEmpty) continue;
      final clubSet = c.clubIds.toSet();
      final p = Repository.instance.players
          .where((pl) => pl.clubs.any(clubSet.contains))
          .toList();
      if (p.length < 12) continue;
      candidates.add(c);
    }
    if (candidates.isEmpty) {
      errorMessage = 'Yeterli havuzlu koç yok.';
    }
  }

  /// Rulet sonucu — coach atanır, pool dolar, slots sıfırlanır
  void applyCoach(Coach c) {
    coach = c;
    final clubSet = c.clubIds.toSet();
    pool = Repository.instance.players
        .where((pl) => pl.clubs.any(clubSet.contains))
        .toList();
    slots = List<Player?>.filled(formation.slots.length, null);
    selectedSlot = null;
    searchQuery = '';
    searchResults = [];
    spinning = false;
    notifyListeners();
  }

  void setSpinning(bool v) {
    spinning = v;
    notifyListeners();
  }

  void setFormation(Formation f) {
    formation = f;
    final old = List<Player?>.from(slots);
    slots = List<Player?>.filled(f.slots.length, null);
    for (var i = 0; i < old.length && i < slots.length; i++) {
      final p = old[i];
      if (p != null && _fitsSlot(p, i)) slots[i] = p;
    }
    selectedSlot = null;
    notifyListeners();
  }

  void selectSlot(int index) {
    selectedSlot = index;
    notifyListeners();
  }

  bool _fitsSlot(Player p, int slotIndex) {
    final slot = formation.slots[slotIndex];
    final det =
        (p.detailedPosition.isNotEmpty ? p.detailedPosition : p.position)
            .toLowerCase();
    final broad = p.position.toLowerCase();

    for (final a in slot.acceptedDetailedPositions) {
      final al = a.toLowerCase();
      if (det.contains(al) ||
          al.contains(det) ||
          det.contains(al.split(' - ').last)) {
        return true;
      }
    }

    final fb = slot.fallbackBroadPosition.toLowerCase();
    if (fb.contains('goal')) return broad.contains('goal');
    if (fb.contains('def')) {
      return broad.contains('def') || broad.contains('back');
    }
    if (fb.contains('mid')) return broad.contains('mid');
    if (fb.contains('att')) {
      return broad.contains('att') ||
          broad.contains('forward') ||
          broad.contains('wing');
    }
    return true;
  }

  void search(String q) {
    searchQuery = q.trim();
    if (searchQuery.length < 2) {
      searchResults = [];
      notifyListeners();
      return;
    }
    final used = slots.whereType<Player>().map((e) => e.id).toSet();
    final hits = SearchService.suggestions(
      players: pool,
      query: searchQuery,
      excludedPlayerIds: used,
      limit: 30,
    );
    searchResults = hits
        .where((p) => selectedSlot == null || _fitsSlot(p, selectedSlot!))
        .toList();
    notifyListeners();
  }

  String? tryPlace(Player player) {
    final index = selectedSlot;
    if (index == null) return 'Önce sahadan bir slot seç.';
    if (!pool.any((p) => p.id == player.id)) {
      return 'Bu oyuncu bu teknik direktörün kulüplerinde yer almıyor.';
    }
    if (!_fitsSlot(player, index)) {
      return 'Pozisyon bu slota uymuyor.';
    }
    if (slots.any((p) => p?.id == player.id)) {
      return 'Oyuncu zaten kadroda.';
    }
    slots[index] = player;
    selectedSlot = null;
    searchQuery = '';
    searchResults = [];
    notifyListeners();
    return null;
  }

  void clearSlot(int index) {
    slots[index] = null;
    notifyListeners();
  }

  Coach randomCandidate() {
    if (candidates.isEmpty) {
      return famousCoachesSeed.first;
    }
    return candidates[_rng.nextInt(candidates.length)];
  }
}
