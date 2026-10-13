import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class WhatIfStore {
  Future<Map<String,dynamic>> read();
  Future<void> write(Map<String,dynamic> value);
}
class LocalWhatIfStore implements WhatIfStore {
  LocalWhatIfStore(String? uid): key='what_if.v1.${uid ?? "guest"}';
  final String key;
  @override
  Future<Map<String,dynamic>> read() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(key);
    return raw==null ? <String,dynamic>{} : Map<String,dynamic>.from(jsonDecode(raw) as Map);
  }
  @override
  Future<void> write(Map<String,dynamic> value) async {
    final prefs=await SharedPreferences.getInstance();
    if(!await prefs.setString(key,jsonEncode(value))) throw StateError('Kader kaydı saklanamadı.');
  }
}
