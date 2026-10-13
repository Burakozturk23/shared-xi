import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/docu_task.dart';
import '../services/football_docu_service.dart';

class FootballDocuController extends ChangeNotifier {
  FootballDocuController({required this.catalog, required this.store, required this.gateway});
  final FootballDocuCatalog catalog;
  final FootballDocuStore store;
  final FootballDocuGateway gateway;
  Map<String, dynamic> hints = {}, files = {};
  bool pro = false;
  Map<String, dynamic> drafts = {}, results = {}, rewards = {}, pending = {};
  String? activeId;
  String phase = 'archive';
  String message = '';
  bool busy = false, ready = false, hintOpen = false, rewardEligible = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  DocuTask? get active => activeId == null ? null : catalog.byId(activeId!);
  List<String> get answers => docuStrings(drafts[activeId]);
  int get count => results.length;
  int get fileCount => files.length;
  bool available(DocuTask t) => t.stage == 1 || results.containsKey('${t.episodeId}-01');
  void openEpisode(String id) {
    final d = catalog.episode(id);
    open(d.taskIds.firstWhere((t) => !results.containsKey(t), orElse: () => d.taskIds.last));
  }
  int get coins => rewards.values.map(docuMap).where((r) => r['settled'] == true)
      .fold(0, (sum, r) => sum + ((r['coins'] as num?)?.toInt() ?? 0));
  bool get canSubmit => phase == 'task' && active != null && answers.length == active!.requiredCount && answers.toSet().length == answers.length && answers.every(active!.optionIds.contains);
  void _notify() { if (!_disposed) notifyListeners(); }
  Map<String, dynamic> _snapshot() => docuMap(jsonDecode(jsonEncode({'storageVersion': catalog.storageVersion,
    'files': files, 'drafts': Map<String, dynamic>.from(drafts), 'results': Map<String, dynamic>.from(results),
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
    final validIds = catalog.tasks.map((m) => m.id).toSet();
    if (s['storageVersion'] == catalog.storageVersion) {
      files = docuMap(s['files'])..removeWhere((id, v) => !catalog.episodes.any((d) => d.id == id) || v is! Map);
      hints = docuMap(s['hints']); pro = s['pro'] == true;
      drafts = docuMap(s['drafts']);
      for (final m in catalog.tasks) {
        final a = docuStrings(drafts[m.id]);
        if (a.where((x) => x.isNotEmpty).toSet().length != a.where((x) => x.isNotEmpty).length || a.any((x) => !(m.interaction == 'match' && x.isEmpty) && !m.optionIds.contains(x)) ||
            (m.ordered ? a.length != m.requiredCount : a.length > m.requiredCount)) drafts.remove(m.id);
      }
      results = docuMap(s['results'])..removeWhere((id, v) => !validIds.contains(id) || v is! Map);
      rewards = docuMap(s['rewards']);
      pending = docuMap(s['pending'])..removeWhere((id, v) => !validIds.contains(id));
      activeId = validIds.contains(s['activeId']) ? s['activeId'] as String : null;
      phase = activeId != null && ['intro','task','result'].contains(s['phase']) ? s['phase'] as String : 'archive';
      if (phase == 'result' && !results.containsKey(activeId)) phase = 'task';
      hintOpen = s['hintOpen'] == true;
      rewardEligible = s['rewardEligible'] == true;
    }
    if (phase == 'task' && active != null && !drafts.containsKey(activeId)) {
      if (active!.interaction == 'match') drafts[activeId!] = List<String>.filled(active!.slots.length, '');
      if (active!.interaction == 'order') drafts[activeId!] = active!.optionIds;
    }
    if (active != null && !available(active!)) phase = 'archive';
    ready = true; _notify();
    await sync();
  }
  void open(String id, {bool replay = false}) {
    if (busy || _disposed || !available(catalog.byId(id))) return;
    activeId = catalog.byId(id).id; hintOpen = false; message = '';
    phase = !replay && results.containsKey(id) ? 'result' : 'intro';
    if (replay) { drafts.remove(id); pending.remove(id); }
    _saveSoon(); _notify();
  }
  void start() {
    if (busy || active == null || !available(active!)) return;
    if (active!.interaction == 'order' && !drafts.containsKey(activeId)) drafts[activeId!] = active!.optionIds;
    if (active!.interaction == 'match' && !drafts.containsKey(activeId)) drafts[activeId!] = List<String>.filled(active!.slots.length, '');
    phase = 'task'; _saveSoon(); _notify();
  }
  void archive() { if (busy) return; phase = 'archive'; _saveSoon(); _notify(); }
  void choose(String id) {
    if (busy || phase != 'task' || active == null || active!.ordered || !active!.optionIds.contains(id)) return;
    if (active!.interaction == 'multi') {
      final a = answers;
      if (a.contains(id)) { a.remove(id); }
      else if (a.length < active!.requiredCount) { a.add(id); }
      else { message = 'Önce bir kartın seçimini kaldır.'; _notify(); return; }
      drafts[activeId!] = a;
    } else { drafts[activeId!] = [id]; }
    pending.remove(activeId); message = ''; _saveSoon(); _notify();
  }
  void move(int index, int delta) {
    if (busy || phase != 'task' || active?.interaction != 'order') return;
    final a = answers, next = index + delta;
    if (index < 0 || index >= a.length || next < 0 || next >= a.length) return;
    final value = a.removeAt(index); a.insert(next, value); drafts[activeId!] = a;
    pending.remove(activeId); message = ''; _saveSoon(); _notify();
  }
  void reorder(int from, int to) {
    if (busy || phase != 'task' || active?.interaction != 'order') return;
    if (to > from) to--;
    move(from, to - from);
  }
  void assign(int slot, String id) {
    if (busy || phase != 'task' || active?.interaction != 'match' || !active!.optionIds.contains(id) || slot < 0 || slot >= active!.slots.length) return;
    final a = answers;
    for (var i = 0; i < a.length; i++) { if (a[i] == id) a[i] = ''; }
    a[slot] = id; drafts[activeId!] = a; pending.remove(activeId); message = ''; _saveSoon(); _notify();
  }
  Future<void> buyHint({required int maxPrice}) async {
    if (_disposed || busy || phase != 'task' || active == null) return;
    busy = true; _notify();
    try { final response = await gateway.call('hint', {'version': catalog.version, 'taskId': activeId, 'maxPrice': maxPrice});
      if (_disposed) return; _merge(response); await _save();
    } catch (e) { if (!_disposed) message = _error(e); }
    finally { busy = false; _notify(); }
  }
  void hint() { hintOpen = !hintOpen; _saveSoon(); _notify(); }
  void _merge(Map<String, dynamic> response) {
    if (response['version'] != catalog.version) throw StateError('İçerik sürümü değişti. Uygulamayı güncelle.');
    final allowed = catalog.tasks.map((m) => m.id).toSet();
    results = docuMap(response['results'])..removeWhere((k, v) => !allowed.contains(k) || v is! Map);
    files = docuMap(response['files'])..removeWhere((id, v) => !catalog.episodes.any((d) => d.id == id) || v is! Map);
    rewards = docuMap(response['rewards']); hints = docuMap(response['hints']); pro = response['pro'] == true;
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
      final response = await gateway.call('submit', {'version': catalog.version, 'taskId': id, 'answers': pending[id]});
      if (_disposed) return;
      if (response['correct'] == true) {
        _merge(response); phase = 'result';
        message = 'Görev kaydedildi. Tekrar oynamak ikinci bir ödül vermez.';
      } else { message = switch (active!.interaction) {
        'order' => 'Olayların sırasını yeniden incele; önce ve sonra ilişkisine bak.',
        'match' => 'Kanıtlardan biri alanıyla uyuşmuyor. Birim, kişi ve maç evresini kontrol et.',
        'multi' => 'Bu kart kümesi kayda uymuyor. Her seçimi sorudaki dönemle karşılaştır.',
        'boolean' => 'Manşeti yeniden değerlendir; iddianın tamamı için aynı kayıt geçerli mi?',
        _ => 'Bu kart olay kaydına uymuyor. Sorudaki tarih ve rolü yeniden incele.',
      }; }
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
        final reply = await gateway.call('submit', {'version': catalog.version, 'taskId': id, 'answers': pending[id]});
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
