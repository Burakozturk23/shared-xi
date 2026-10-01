import 'package:cloud_functions/cloud_functions.dart';
import '../../models/season_pass.dart';
import '../auth_service.dart';
import '../cloud_bootstrap.dart';

class SeasonGateway {
  const SeasonGateway();
  bool get connected => AuthService.isGoogleAccount;
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> input,
  ) async {
    await CloudBootstrap.ensureInitialized();
    if (!connected) throw StateError('Google hesabını bağla.');
    final uid = AuthService.uid;
    final response = await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable(name).call(input);
    if (uid != AuthService.uid)
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<SeasonPass> load() async =>
      SeasonPass.fromMap(await _call('getSeasonPass', {}));
  Future<SeasonPass> claim(String id, int step, String lane) async {
    final result = await _call('claimSeasonReward', {
      'seasonId': id,
      'step': step,
      'lane': lane,
    });
    return SeasonPass.fromMap(
      Map<String, dynamic>.from(result['profile'] as Map),
    );
  }
}
