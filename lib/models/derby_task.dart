import 'dart:convert';
import 'package:flutter/services.dart';
Map<String,dynamic> derbyMap(dynamic raw) => raw is Map ? Map<String,dynamic>.from(raw) : <String,dynamic>{};
List<String> derbyStrings(dynamic raw) => raw is List ? raw.whereType<String>().toList() : <String>[];
String derbySearch(String value) {
  var text=value.toLowerCase();
  const replacements={'ı':'i','İ':'i','ş':'s','ğ':'g','ü':'u','ö':'o','ç':'c','é':'e','è':'e','ê':'e','á':'a','à':'a','ã':'a','â':'a','í':'i','ó':'o','ô':'o','ñ':'n','ć':'c','č':'c'};
  replacements.forEach((a,b){text=text.replaceAll(a,b);});
  return text.replaceAll(RegExp(r'[^a-z0-9]'),'');
}
class DerbyTask {
  DerbyTask(this.data);
  final Map<String,dynamic> data;
  String text(String key)=>data[key]?.toString()??'';
  String get id=>text('id');
  String get interaction=>text('interaction');
  String get mechanic=>text('mechanic');
  int get requiredCount=>data['requiredCount'] as int;
  bool get ordered=>interaction=='order';
  List<String> get clubs=>derbyStrings(data['clubs']);
  List<Map<String,dynamic>> get options=>(data['options'] as List).map(derbyMap).toList();
  List<String> get optionIds=>options.map((o)=>o['id'] as String).toList();
  String optionLabel(String id)=>options.firstWhere((o)=>o['id']==id)['label'] as String;
  String get label=>switch(mechanic){'memory'=>'Derbi Hafızası','identity'=>'Rekabetin Kimliği','timeline'=>'Rekabet Kronolojisi','two_shirts'=>'İki Formanın Hikâyesi',_=>'Derbi Efsanesi'};
}
class DerbyDayCatalog {
  DerbyDayCatalog(Map<String,dynamic> data):version=data['version'] as int,storageVersion=data['storageVersion'] as int,countries=derbyStrings(data['countries']),economy=derbyMap(data['economy']),tasks=(data['tasks'] as List).map((t)=>DerbyTask(derbyMap(t))).toList();
  final int version,storageVersion;
  final List<String> countries;
  final Map<String,dynamic> economy;
  final List<DerbyTask> tasks;
  DerbyTask byId(String id)=>tasks.firstWhere((t)=>t.id==id);
  static Future<DerbyDayCatalog> load()async=>DerbyDayCatalog(derbyMap(jsonDecode(await rootBundle.loadString('assets/data/derby_day_v2.json'))));
}
