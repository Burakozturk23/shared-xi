import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/career_transfer_service.dart';
import 'package:shared_xi/services/three_modes_service.dart';
import 'package:shared_xi/services/arcade_service.dart';

class _Ads extends EnergyService {
  bool? skipAd;
  Map<String, dynamic>? selection;
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async => {'pro': true};
  @override
  Future<void> watch(String placement, {required bool pro, Map<String, dynamic>? context}) async {
    skipAd = pro;
    selection = context;
  }
}

void main() {
  for (final family in ['career', 'three', 'arcade']) {
    test('$family typed support loads a real ad for Pro while legacy rights remain', () async {
      final transport = _Ads();
      Future<void> watch(String? sku) => switch (family) {
        'career' => CareerTransferService(transport: transport).watchHint('transfer', 'run', boostId: sku),
        'three' => ThreeModesService(transport: transport).watchHint('coach_xi', 'run', boostId: sku),
        _ => ArcadeService(transport: transport, currentUser: () => 'alice').watch('run', boostId: sku),
      };
      await watch('boost_basic');
      expect(transport.skipAd, false);
      expect(transport.selection, {'sessionId': 'run', 'boostId': 'boost_basic'});
      await watch(null);
      expect(transport.skipAd, true);
      expect(transport.selection, {'sessionId': 'run'});
    });
  }
}
