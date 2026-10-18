import 'package:flutter/material.dart';
import '../services/daily_words_service.dart';
import 'daily_words_page.dart';

class PassaparolaPage extends StatelessWidget {
  const PassaparolaPage({super.key, this.service});
  final DailyWordsService? service;
  @override
  Widget build(BuildContext context) => DailyWordsPage(mode: 'passa_daily', service: service);
}
