import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'energy_service.dart';
import '../models/rewarded_ad_models.dart';

/// Only sends intentions. Scores, clocks, winners and rewards come from the referee.
class PvpService {
  PvpService({EnergyService? transport, String? Function()? currentUser})
      : transport = transport ?? EnergyService(), currentUser = currentUser ?? (() => AuthService.uid);
  final EnergyService transport;
  final String? Function() currentUser;
  String? owner;
  String? revision;
  Map<String,dynamic> protocol(String mode) => {'mode': mode, 'schemaVersion': 1,
    'ruleVersion': 'PVP_RULES_V1', if (revision != null) 'dataRevision': revision};
  void check(String? uid) {
    if (uid == null || currentUser() != uid || owner != null && owner != uid) {
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    }
    owner = uid;
  }
  Future<Map<String,dynamic>> load(String mode) async {
    final uid = currentUser();
    check(uid);
    final r = await transport.call('getPvp', protocol(mode));
    check(uid);
    revision = '${r['dataRevision']}';
    final prefs = await SharedPreferences.getInstance(); check(uid);
    if (prefs.containsKey('pvp.v1.$uid.$mode.pending')) {
      // Replay the persisted action before accepting a new intention after retry/restart.
      final recovered = await send('actPvp', mode, {'action': 'poll'});
      if (recovered['room'] != null) r['room'] = recovered['room'];
    }
    return r;
  }
  Future<Map<String,dynamic>> send(String call, String mode, Map<String,dynamic> input) async {
    final uid = currentUser(); check(uid);
    final prefs = await SharedPreferences.getInstance(); check(uid);
    final key = 'pvp.v1.$uid.$mode.pending';
    final saved = prefs.getString(key);
    final request = saved == null ? {'call': call, 'input': {...protocol(mode), ...input,
      if (input['action'] != 'poll') 'actionId': EnergyService.requestId()}} : rewardMap(jsonDecode(saved));
    if (saved == null && input['action'] != 'poll') {
      if (!await prefs.setString(key, jsonEncode(request))) throw StateError('İstek kaydedilemedi.');
      check(uid);
    }
    try {
      final r = await transport.call('${request['call']}', rewardMap(request['input'])); check(uid);
      await prefs.remove(key); check(uid); return r;
    } on FirebaseFunctionsException catch (e) {
      check(uid);
      if (!['unavailable','deadline-exceeded','internal','unknown','cancelled'].contains(e.code)) {
        await prefs.remove(key); check(uid);
      }
      rethrow;
    }
  }
  Future<Map<String,dynamic>> enter(String mode, String kind, String action, {String? code, String profile = 'standard'}) =>
    send('enterPvp', mode, {'playKind': kind,'action': action,'profile': profile,if (code != null) 'code': code});
  Future<Map<String,dynamic>> act(Map<String,dynamic> room, String action, [Map<String,dynamic> extra = const {}]) =>
    send('actPvp', '${room['mode']}', {'roomId': room['id'],'revision': room['revision'],'action': action,...extra});
  Future<List<Map<String,dynamic>>> search(String mode, String query, {String? roomId}) async {
    final uid = currentUser(); check(uid);
    final r = await transport.call('searchPvp', {...protocol(mode),'query': query,if (roomId != null) 'roomId': roomId});
    check(uid); return (r['players'] as List? ?? []).map(rewardMap).toList();
  }
}
