import 'package:flutter/material.dart';
import '../services/daily_words_service.dart';
import 'daily_words_page.dart';

class FutbolLingoPage extends StatelessWidget {
  const FutbolLingoPage({super.key, this.service});
  final DailyWordsService? service;
  @override
  Widget build(BuildContext context) => DailyWordsPage(mode: 'daily_lingo', service: service);
}
