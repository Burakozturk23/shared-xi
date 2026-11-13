import 'manager_pool.dart';

class ManagerTransferOffer {
  final ManagerPoolPlayer player;
  final int askLink; // istenen ücret (tier cost ±)
  final String note;

  const ManagerTransferOffer({
    required this.player,
    required this.askLink,
    required this.note,
  });
}
