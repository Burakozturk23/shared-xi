import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'energy_service.dart';

/// A durable mutation journal keeps a timed-out pick/start from being charged twice.
/// The server owns answers, progression, ad receipts, dates and energy.
class ThreeModesService {
  ThreeModesService({EnergyService? transport}) : _transport = transport ?? EnergyService();
  final EnergyService _transport;

  Future<Map<String, dynamic>> _replay(SharedPreferences prefs, String key) async {
    final pending = rewardMap(jsonDecode(prefs.getString(key)!));
    try {
      final result = await _transport.call('${pending['call']}', rewardMap(pending['input']));
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
    final prefs = await SharedPreferences.getInstance();
    final key = 'three_modes.pending.${user.uid}.$mode';
    Map<String, dynamic>? recovered;
    if (prefs.containsKey(key)) recovered = await _replay(prefs, key);
    final status = await _transport.call('getThreeMode', {'mode': mode});
    status['energy'] = await _transport.status();
    if (recovered?['session'] is Map) status['session'] = recovered!['session'];
    return status;
  }

  Future<Map<String, dynamic>> mutate(String name, Map<String, dynamic> input) async {
    final user = await AuthService.ensureGuestSignedIn();
    final prefs = await SharedPreferences.getInstance();
    final key = 'three_modes.pending.${user.uid}.${input['mode']}';
    if (prefs.containsKey(key)) throw StateError('Önce bekleyen işlemi Yenile ile tamamla.');
    final payload = {...input, 'requestId': EnergyService.requestId()};
    if (!await prefs.setString(key, jsonEncode({'call': name, 'input': payload}))) {
      throw StateError('İşlem cihazda kaydedilemedi. Tekrar dene.');
    }
    return _replay(prefs, key);
  }

  Future<Map<String, dynamic>> search(Map<String, dynamic> input) =>
      _transport.call('searchThreeMode', input);

  Future<void> watchHint(String mode, String sessionId, {String? boostId}) async {
    final status = await _transport.call('getRewardedAdStatus');
    await _transport.watch(
      {'coach_xi': 'coach11_hint', 'letter11': 'letter11_hint', 'squad_vault': 'vault_hint'}[mode]!,
      pro: boostId == null && status['pro'] == true, context: {'sessionId': sessionId, if (boostId != null) 'boostId': boostId},
    );
  }
}
