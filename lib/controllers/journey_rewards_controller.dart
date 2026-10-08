import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journey_task.dart';
import '../services/auth_service.dart';
import '../services/journey_gateway.dart';
import '../models/rewarded_ad_models.dart';

class JourneyRewardsController extends ChangeNotifier {
  JourneyRewardsController({JourneyGateway? gateway, String? userId})
    : gateway = gateway ?? FirebaseJourneyGateway(),
      _injected = gateway != null,
      uid = userId ?? (AuthService.isGoogleAccount ? AuthService.uid : null);
  final JourneyGateway gateway;
  final String? uid;
  final bool _injected;
  bool busy = false, _disposed = false, _again = false;
  Map<String,dynamic> data = {};
  String? message;
  static Future<void> _writes = Future.value();
  bool get linked => uid != null && (_injected || (AuthService.isGoogleAccount && AuthService.uid == uid));
  String get _key => 'journey.proofs.v1.$uid';
  Set<String> get completed => (data['completed'] as List? ?? []).map((e)=>e.toString()).toSet();
  List<String> get favorites => (data['favorites'] as List? ?? []).map((e)=>e.toString()).toList();
  bool get legend => data['finalUnlocked'] == true;
  bool get pro => data['pro'] == true;
  Map<String,dynamic> get rewards => rewardMap(data['rewards']);
  Map<String,dynamic> hints(String task) => rewardMap(rewardMap(data['hints'])[task]);
  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }
  Future<T> _locked<T>(Future<T> Function() action) {
    final next = _writes.then((_)=>action());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
  Future<Map<String,dynamic>> _queue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == null ? {} : rewardMap(jsonDecode(raw));
  }
  Future<void> _write(Map<String,dynamic> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key,jsonEncode(queue))) throw StateError('Cevap kaydedilemedi.');
  }
  // Persist evidence before local advancement. A network failure never consumes
  // the evidence; only a server acknowledgement removes it, scoped to this UID.
  Future<void> enqueue(String journeyId, JourneyTask task, List<String> answers) async {
    if (!linked) return;
    await _locked(() async {
      final queue = await _queue();
      queue[task.id] = {'version':1,'journeyId':journeyId,'taskId':task.id,'answers':answers};
      await _write(queue);
    });
    unawaited(refresh());
  }
  Future<void> refresh() async {
    if (_disposed) return;
    if (!linked) {
      data = {}; message = 'Ödüller ve profil vitrini için Google hesabına bağlan. Cihazdaki ilerlemen korunur.';
      _notify(); return;
    }
    if (busy) { _again = true; return; }
    busy = true; message = null; _notify();
    try {
      final queue = await _locked(_queue);
      final entries = queue.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
      final blocked = <String>{};
      var pending = false;
      for (final entry in entries) {
        if (!linked) throw StateError('Hesap değişti. Ekranı yeniden aç.');
        final proof = rewardMap(entry.value);
        final journey = proof['journeyId'].toString();
        if (blocked.contains(journey)) continue;
        try {
          await gateway.call('submit',proof);
          if (!linked) throw StateError('Hesap değişti.');
          await _locked(() async { final latest = await _queue(); latest.remove(entry.key); await _write(latest); });
        } catch (_) {
          blocked.add(journey); pending = true;
        }
      }
      final result = await gateway.call('status');
      if (!linked) throw StateError('Hesap değişti.');
      data = result;
      if (pending) message = 'Bazı cevaplar eşitlenmeyi bekliyor. Eski aşamalardan devam ettiysen ödül için o yolculuğu baştan tamamla. Diğer kariyerlerin etkilenmez.';
    } catch (_) {
      message = 'Ödüller henüz eşitlenemedi. Cevapların bu hesap için saklanıyor; bağlantı gelince yeniden dene. Eski aşamalardan devam ettiysen ödül için bu yolculuğu tekrar tamamla.';
    } finally {
      busy = false; _notify();
      if (_again) { _again = false; unawaited(refresh()); }
    }
  }
  Future<void> action(String action, Map<String,dynamic> input, {bool ad = false}) async {
    if (!linked) { await refresh(); return; }
    if (busy) return;
    busy = true; message = null; _notify();
    try {
      if (ad) { await gateway.watch(action,context:input); }
      else { await gateway.call(action,input); }
      if (!linked) throw StateError('Hesap değişti.');
      data = await gateway.call('status');
      if (!linked) { data = {}; throw StateError('Hesap değişti.'); }
    } catch (e) {
      message = e is StateError ? e.message.toString() : 'İşlem tamamlanamadı. Ödülünü veya yardımını yeniden kontrol edebilirsin.';
    } finally {
      busy = false; _notify();
      if (_again) { _again = false; unawaited(refresh()); }
    }
  }
}
