import 'package:flutter/material.dart';
import '../models/career_puzzle_state.dart';
import 'career_transfer_page.dart';

class CareerPuzzlePage extends StatelessWidget {
  const CareerPuzzlePage({super.key, this.difficulty = CareerPuzzleDifficulty.normal});
  final CareerPuzzleDifficulty difficulty;
  @override
  Widget build(BuildContext context) => CareerTransferPage(mode: 'career', difficulty: difficulty.name);
}
