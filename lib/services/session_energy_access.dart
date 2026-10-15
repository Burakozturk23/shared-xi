import '../models/energy_session.dart';
import '../models/rewarded_ad_models.dart';
import 'energy_service.dart';

abstract interface class SessionEnergyAccess {
  String newRequestId();
  int get nowMs;
  Future<EnergySession> reserve(String id);
  Future<EnergySession> confirm(EnergySession session);
  Future<EnergySession> resume(EnergySession session);
}

/// The controller saves a reservation before confirmation. A lost confirmation
/// response is retried with the same ID; it never creates a second paid game.
class ServerSessionEnergyAccess implements SessionEnergyAccess {
  ServerSessionEnergyAccess(this.mode, {EnergyService? service})
      : service = service ?? EnergyService();
  final String mode;
  final EnergyService service;
  int _clockOffset = 0;
  @override
  int get nowMs => DateTime.now().millisecondsSinceEpoch + _clockOffset;
  @override
  String newRequestId() => EnergyService.requestId();
  EnergySession _read(Map<String, dynamic> result, String id) {
    final serverNow = result['serverNow'];
    if (serverNow is num) {
      _clockOffset = serverNow.toInt() - DateTime.now().millisecondsSinceEpoch;
    }
    if (result['enabled'] == false) return EnergySession(id: id, status: 'free');
    return EnergySession.fromJson(rewardMap(result['session']));
  }
  @override
  Future<EnergySession> reserve(String id) async => _read(await service.call(
    'startEnergySession', {'mode': mode, 'requestId': id}), id);
  @override
  Future<EnergySession> confirm(EnergySession session) async => _read(await service.call(
    'confirmEnergySession', {'sessionId': session.id}), session.id);
  @override
  Future<EnergySession> resume(EnergySession session) async => _read(await service.call(
    'resumeEnergySession', {'sessionId': session.id, 'mode': mode}), session.id);
}
