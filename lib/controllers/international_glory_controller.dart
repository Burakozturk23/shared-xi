import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/international_match.dart';
import '../services/international_glory_service.dart';

class InternationalGloryController extends ChangeNotifier {
  InternationalGloryController({required this.catalog, required this.store, required this.gateway});
  final InternationalCatalog catalog;
  final InternationalStore store;
  final InternationalGateway gateway;
  Map<String, dynamic> hints = {};
  bool pro = false;
  Map<String, dynamic> drafts = {}, results = {}, rewards = {}, pending = {};
  String? activeId;
  String phase = 'archive';
  String message = '';
  bool busy = false, ready = false, hintOpen = false, rewardEligible = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  InternationalMatch? get active => activeId == null ? null : catalog.byId(activeId!);
  List<String> get answers => igStrings(drafts[activeId]);
  int get count => results.length;
  int get coins => rewards.values.map(igMap).where((r) => r['settled'] == true)
      .fold(0, (sum, r) => sum + ((r['coins'] as num?)?.toInt() ?? 0));
  bool get canSubmit => active != null && answers.length == (active!.ordered ? active!.options.length : 1) && answers.toSet().length == answers.length && answers.every(active!.optionIds.contains);
  void _notify() { if (!_disposed) notifyListeners(); }
  Map<String, dynamic> _snapshot() => igMap(jsonDecode(jsonEncode({'version': catalog.version,
    'drafts': Map<String, dynamic>.from(drafts), 'results': Map<String, dynamic>.from(results),
    'rewards': Map<String, dynamic>.from(rewards), 'pending': Map<String, dynamic>.from(pending),
    'activeId': activeId, 'phase': phase, 'hintOpen': hintOpen, 'rewardEligible': rewardEligible, 'hints': hints, 'pro': pro})));
  Future<void> _save() {
    final snapshot = _snapshot();
    final operation = _writes.then((_) async {
      try { await store.write(snapshot); } catch (_) {
        throw StateError('Cihaz kaydı yazılamadı. Çıkmadan önce yeniden dene.');
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
  void _saveSoon() { _save().catchError((Object _) {
    message = 'Cihaz kaydı yazılamadı. Çıkmadan önce yeniden dene.'; _notify();
  }); }
  Future<void> load() async {
    final s = await store.read();
    if (_disposed) return;
    final validIds = catalog.matches.map((m) => m.id).toSet();
    if (s['version'] == catalog.version) {
      hints = igMap(s['hints']); pro = s['pro'] == true;
      drafts = igMap(s['drafts']);
      for (final m in catalog.matches) {
        final a = igStrings(drafts[m.id]);
        if (a.where((x) => x.isNotEmpty).toSet().length != a.where((x) => x.isNotEmpty).length || a.any((x) => !(m.type == 'route' && x.isEmpty) && !m.optionIds.contains(x)) ||
            (m.ordered ? a.length != m.options.length : a.length > 1)) drafts.remove(m.id);
      }
      results = igMap(s['results'])..removeWhere((id, v) => !validIds.contains(id) || v is! Map);
      rewards = igMap(s['rewards']);
      pending = igMap(s['pending'])..removeWhere((id, v) => !validIds.contains(id));
      activeId = validIds.contains(s['activeId']) ? s['activeId'] as String : null;
      phase = activeId != null && ['intro','task','result'].contains(s['phase']) ? s['phase'] as String : 'archive';
      if (phase == 'result' && !results.containsKey(activeId)) phase = 'task';
      hintOpen = s['hintOpen'] == true;
      rewardEligible = s['rewardEligible'] == true;
    }
    ready = true; _notify();
    await sync();
  }
  void open(String id, {bool replay = false}) {
    if (busy) return;
    activeId = catalog.byId(id).id; hintOpen = false; message = '';
    phase = !replay && results.containsKey(id) ? 'result' : 'intro';
    if (replay) { drafts.remove(id); pending.remove(id); }
    _saveSoon(); _notify();
  }
  void start() {
    if (busy || active == null) return;
    if (active!.type == 'timeline' && !drafts.containsKey(activeId)) drafts[activeId!] = active!.optionIds;
    if (active!.type == 'route' && !drafts.containsKey(activeId)) drafts[activeId!] = List<String>.filled(active!.slots.length, '');
    phase = 'task'; _saveSoon(); _notify();
  }
  void archive() { if (busy) return; phase = 'archive'; _saveSoon(); _notify(); }
  void choose(String id) {
    if (busy || phase != 'task' || active == null || active!.ordered || !active!.optionIds.contains(id)) return;
    drafts[activeId!] = [id]; pending.remove(activeId); message = ''; _saveSoon(); _notify();
  }
  void move(int index, int delta) {
    if (busy || active?.type != 'timeline') return;
    final a = answers, next = index + delta;
    if (index < 0 || index >= a.length || next < 0 || next >= a.length) return;
    final value = a.removeAt(index); a.insert(next, value); drafts[activeId!] = a;
    pending.remove(activeId); message = ''; _saveSoon(); _notify();
  }
  void assign(int slot, String id) {
    if (busy || phase != 'task' || active?.type != 'route' || !active!.optionIds.contains(id) || slot < 0 || slot >= active!.slots.length) return;
    final a = answers;
    for (var i = 0; i < a.length; i++) { if (a[i] == id) a[i] = ''; }
    a[slot] = id; drafts[activeId!] = a; pending.remove(activeId); message = ''; _saveSoon(); _notify();
  }
  Future<void> buyHint() async {
    if (busy || active == null) return;
    busy = true; _notify();
    try { final response = await gateway.call('hint', {'version': catalog.version, 'matchId': activeId});
      if (_disposed) return; _merge(response); await _save();
    } catch (e) { if (!_disposed) message = _error(e); }
    finally { busy = false; _notify(); }
  }
  void hint() { hintOpen = !hintOpen; _saveSoon(); _notify(); }
  void _merge(Map<String, dynamic> response) {
    if (response['version'] != catalog.version) throw StateError('İçerik sürümü değişti. Uygulamayı güncelle.');
    final allowed = catalog.matches.map((m) => m.id).toSet();
    results = igMap(response['results'])..removeWhere((k, v) => !allowed.contains(k) || v is! Map);
    rewards = igMap(response['rewards']); hints = igMap(response['hints']); pro = response['pro'] == true;
    rewardEligible = response['rewardEligible'] == true;
  }
  String _error(Object e) {
    if (e is StateError) return e.message;
    if (e is FirebaseFunctionsException && ['failed-precondition','permission-denied'].contains(e.code)) {
      return e.message ?? 'Doğrulama yapılamadı.';
    }
    return 'Şu an sunucuya ulaşılamıyor. Seçimlerin saklandı; bağlantı gelince “Eşitle” ile devam et.';
  }
  Future<void> submit() async {
    if (busy || !canSubmit) return;
    final id = activeId!;
    pending[id] = List<String>.from(answers);
    busy = true; message = ''; _notify();
    try {
      await _save();
      final response = await gateway.call('submit', {'version': catalog.version, 'matchId': id, 'answers': pending[id]});
      if (_disposed) return;
      if (response['correct'] == true) {
        _merge(response); phase = 'result';
        message = 'Hatıra kaydedildi. Tekrar oynamak ikinci bir ödül vermez.';
      } else { message = 'Henüz doğru değil. İpucuna bakıp yeniden deneyebilirsin.'; }
      pending.remove(id); await _save();
    } catch (e) { if (!_disposed) message = _error(e); }
    finally { busy = false; _notify(); }
  }
  Future<void> sync() async {
    if (busy || _disposed) return;
    busy = true; _notify();
    try {
      final response = await gateway.call('status');
      if (_disposed) return;
      _merge(response); message = '';
      for (final id in List<String>.from(pending.keys)) {
        final reply = await gateway.call('submit', {'version': catalog.version, 'matchId': id, 'answers': pending[id]});
        if (_disposed) return;
        if (reply['correct'] == true) {
          _merge(reply);
          if (id == activeId && phase == 'task') phase = 'result';
        } else { message = 'Bekleyen cevaplardan biri doğru değil. Görevi açıp yeniden dene.'; }
        pending.remove(id); await _save();
      }
      await _save();
    } catch (e) { if (!_disposed) message = _error(e); }
    finally { busy = false; _notify(); }
  }
  @override
  void dispose() { _disposed = true; super.dispose(); }
}
