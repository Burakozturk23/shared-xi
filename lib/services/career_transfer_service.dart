import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'energy_service.dart';

class CareerTransferService {
  CareerTransferService({EnergyService? transport, this.mysteryChain = false, this.fakeClub = false}) : transport = transport ?? EnergyService();
  final EnergyService transport;
  final bool mysteryChain;
  final bool fakeClub;
  String? owner;
  void _checkOwner(String uid) {
    if (AuthService.uid != uid || owner != null && owner != uid) {
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    }
    owner = uid;
  }
  Future<Map<String, dynamic>> _replay(SharedPreferences prefs, String key, String uid) async {
    final pending = rewardMap(jsonDecode(prefs.getString(key)!));
    _checkOwner(uid);
    try {
      final result = await transport.call('${pending['call']}', rewardMap(pending['input']));
      _checkOwner(uid);
      if (result['room'] is Map) {
        final room = rewardMap(result['room']);
        await prefs.setString('career_transfer.room.$uid.${room['mode']}', '${room['id']}');
      }
      await prefs.remove(key);
      return result;
    } on FirebaseFunctionsException catch (e) {
      if (!['unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled'].contains(e.code)) {
        await prefs.remove(key);
      }
      rethrow;
    }
  }
  Future<Map<String, dynamic>> load(String mode) async {
    final user = await AuthService.ensureGuestSignedIn();
    _checkOwner(user.uid);
    final prefs = await SharedPreferences.getInstance();
    final key = 'career_transfer.pending.${user.uid}.$mode';
    if (prefs.containsKey(key)) await _replay(prefs, key, user.uid);
    final result = await transport.call(fakeClub ? 'getFakeClub' : mysteryChain ? 'getMysteryChain' : 'getCareerTransfer', {'mode': mode});
    result['energy'] = await transport.status();
    _checkOwner(user.uid);
    return result;
  }
  Future<Map<String, dynamic>> mutate(String call, Map<String, dynamic> input) async {
    final user = await AuthService.ensureGuestSignedIn();
    _checkOwner(user.uid);
    final prefs = await SharedPreferences.getInstance();
    final key = 'career_transfer.pending.${user.uid}.${input['mode']}';
    if (prefs.containsKey(key)) throw StateError('Önce Yenile ile bekleyen işlemi tamamla.');
    if (!await prefs.setString(key, jsonEncode({'call': call,
      'input': {...input, 'requestId': EnergyService.requestId()}}))) {
      throw StateError('İşlem kaydedilemedi; tekrar dene.');
    }
    return _replay(prefs, key, user.uid);
  }
  Future<Map<String, dynamic>> onlineLoad(String mode) async {
    final user = await AuthService.ensureGuestSignedIn();
    _checkOwner(user.uid);
    final prefs = await SharedPreferences.getInstance();
    final key = 'career_transfer.pending.${user.uid}.$mode';
    if (prefs.containsKey(key)) await _replay(prefs, key, user.uid);
    final status = await transport.call(mode == 'fake_club_duel' ? 'getFakeClub' : mode == 'mystery_duel' ? 'getMysteryChain' : 'getCareerTransfer',
      {'mode': mode == 'fake_club_duel' ? 'fake_endless' : mode == 'mystery_duel' ? 'mystery' : mode == 'career_race' ? 'career' : 'transfer'});
    final roomId = prefs.getString('career_transfer.room.${user.uid}.$mode');
    if (roomId != null) {
      try {
        final r = await transport.call('actCareerTransferOnline', {'mode': mode, 'version': status['version'],
          'roomId': roomId, 'action': 'poll'});
        status['room'] = r['room'];
      } on FirebaseFunctionsException catch (e) {
        if (!['not-found', 'permission-denied'].contains(e.code)) rethrow;
        _checkOwner(user.uid);
        await prefs.remove('career_transfer.room.${user.uid}.$mode');
      }
    }
    _checkOwner(user.uid);
    return status;
  }
  Future<Map<String, dynamic>> poll(Map<String, dynamic> input) => transport.call('actCareerTransferOnline', input);
  Future<Map<String, dynamic>> search(Map<String, dynamic> input) => transport.call(mysteryChain ? 'searchMysteryChain' : 'searchCareerTransfer', input);
  Future<void> watchHint(String mode, String sessionId) async {
    final status = await transport.call('getRewardedAdStatus');
    await transport.watch('${mode == 'fake_endless' ? 'fake_club' : mode == 'mastermind' ? 'chain' : mode}_hint', pro: status['pro'] == true, context: {'sessionId': sessionId});
  }
}
