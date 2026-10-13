import 'dart:convert';
import 'package:flutter/services.dart';

/// Append-only content; legacy asset versions and local storage keys stay stable.
Future<Map<String, dynamic>> loadFiveModeExpansion() async {
  final data = jsonDecode(await rootBundle.loadString(
    'assets/data/five_mode_expansion.json')) as Map<String, dynamic>;
  if (data['version'] != 1 || data['id'] != 'five-mode-2026-10') {
    throw const FormatException('Genişleme paketi sürümü desteklenmiyor.');
  }
  return data;
}
