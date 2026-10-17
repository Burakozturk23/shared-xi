import '../models/chain_state.dart';
import 'mystery_chain_page.dart';
class ChainPage extends MysteryChainPage {
  const ChainPage({super.key, ChainGameMode mode = ChainGameMode.mastermind})
    : super(mode: mode == ChainGameMode.blitz ? 'blitz' : 'mastermind');
}
