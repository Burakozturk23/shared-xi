import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/energy_service.dart';

class ExpiringProService extends EnergyService {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    calls.add(name);
    if (name == 'prepareRewardedAd') {
      // Membership expired after the panel was loaded. No ad was preloaded.
      return {'pro': false, 'userId': 'alice', 'ticket': {
        'id': 'a' * 48, 'placement': 'energy_refill', 'amount': 0,
        'unitId': 'ca-app-pub-1234567890123456/1234567890',
        'status': 'pending', 'expiresAt': 1}};
    }
    return {'ok': true};
  }
}

void main() {
  test('expired Pro cancels an unseen ticket so it cannot lock the next bonus', () async {
    final service = ExpiringProService();
    await expectLater(service.watch('energy_refill', pro: true), throwsStateError);
    expect(service.calls, ['prepareRewardedAd', 'cancelRewardedAd']);
  });
}
