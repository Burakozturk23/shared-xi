import 'manager_pool.dart';
import 'manager_rating.dart';

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
