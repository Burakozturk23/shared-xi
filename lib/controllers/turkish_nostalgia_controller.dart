import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/turkish_nostalgia_state.dart';
import '../services/nostalgia_service.dart';

class TurkishNostalgiaController extends ChangeNotifier {
  TurkishNostalgiaController({
    required this.catalog,
    required this.store,
    required this.gateway,
  });
  final NostalgiaCatalog catalog;
  final NostalgiaStore store;
  final NostalgiaGateway gateway;
  final Set<String> solved = {}, confirmed = {}, hints = {};
  Map<String, dynamic> drafts = {}, pending = {}, rewards = {};
  String? activeId;
  int taskIndex = 0;
  String phase = 'archive', message = '';
  bool ready = false,
      busy = false,
      syncing = false,
      pro = false,
      rewardEligible = false,
      hintOpen = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  NostalgiaChapter? get active =>
      activeId == null ? null : catalog.chapter(activeId!);
  NostalgiaTask? get task => active?.tasks[taskIndex];
  List<String> get answers => nostalgiaStrings(drafts[task?.id]);
  int count(NostalgiaChapter c) =>
      c.tasks.where((t) => solved.contains(t.id)).length;
  int get albums => catalog.chapters.where((c) => count(c) == 2).length;
  int get coins => rewards.values
      .map(nostalgiaMap)
      .where((r) => r['settled'] == true)
      .fold(0, (n, r) => n + ((r['coins'] as num?)?.toInt() ?? 0));
  bool get canSubmit =>
      task != null &&
      answers.length == task!.answerKeys.length &&
      answers.toSet().length == answers.length &&
      answers.every(task!.optionIds.contains);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save() {
    // Deep snapshot prevents subsequent edits from mutating a queued checkpoint.
    final snapshot = nostalgiaMap(
      jsonDecode(
        jsonEncode({
          'schema': 2,
          'solved': solved.toList(),
          'confirmed': confirmed.toList(),
          'hints': hints.toList(),
          'drafts': drafts,
          'pending': pending,
          'rewards': rewards,
          'activeId': activeId,
          'taskIndex': taskIndex,
          'phase': phase,
          'hintOpen': hintOpen,
        }),
      ),
    );
    final operation = _writes.then((_) => store.write(snapshot));
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  void _saveSoon() {
    unawaited(
      _save().catchError((Object _) {
        message =
            'Cihaz kaydı yazılamadı. Çıkmadan önce Eşitle ile yeniden dene.';
        _notify();
      }),
    );
  }

  Future<void> load() async {
    final s = await store.read();
    if (_disposed) return;
    if (s.isNotEmpty && s['schema'] != 2) {
      throw const FormatException('Kayıt sürümü desteklenmiyor.');
    }
    final ids = catalog.tasks.map((t) => t.id).toSet();
    solved.addAll(nostalgiaStrings(s['solved']).where(ids.contains));
    confirmed.addAll(nostalgiaStrings(s['confirmed']).where(ids.contains));
    hints.addAll(nostalgiaStrings(s['hints']).where(ids.contains));
    drafts = nostalgiaMap(s['drafts']);
    pending = nostalgiaMap(s['pending']);
    for (final t in catalog.tasks) {
      final a = nostalgiaStrings(drafts[t.id]);
      if (a.any(
            (id) =>
                !(id.isEmpty && t.mechanic == 'route') &&
                !t.optionIds.contains(id),
          ) ||
          a.toSet().length != a.length ||
          a.length > t.answerKeys.length) {
        drafts.remove(t.id);
      }
      if (!t.accepts(nostalgiaStrings(pending[t.id]))) pending.remove(t.id);
    }
    pending.removeWhere((id, _) => !ids.contains(id));
    // Only known stable task IDs are reused; the legacy controller had no save.
    for (final c in catalog.chapters) {
      if (!solved.contains(c.tasks.first.id)) solved.remove(c.tasks.last.id);
    }
    rewards = nostalgiaMap(s['rewards']);
    if (catalog.chapters.any((c) => c.id == s['activeId'])) {
      activeId = s['activeId'] as String;
      taskIndex = s['taskIndex'] == 1 && solved.contains(active!.tasks.first.id)
          ? 1
          : 0;
      phase =
          ['intro', 'task', 'result', 'archive', 'album'].contains(s['phase'])
          ? s['phase'] as String
          : 'archive';
      if (phase == 'result' && !solved.contains(task!.id)) phase = 'task';
    }
    hintOpen = s['hintOpen'] == true;
    ready = true;
    _notify();
    unawaited(sync());
  }

  void open(String id, {bool replay = false}) {
    if (busy) return;
    activeId = catalog.chapter(id).id;
    taskIndex = replay ? 0 : (count(active!) == 1 ? 1 : 0);
    phase = 'intro';
    hintOpen = false;
    message = '';
    if (replay) {
      for (final t in active!.tasks) {
        drafts.remove(t.id);
      }
    }
    _saveSoon();
    _notify();
  }

  void start() {
    if (busy || task == null) return;
    if (task!.mechanic == 'timeline' && !drafts.containsKey(task!.id)) {
      drafts[task!.id] = task!.optionIds;
    }
    phase = 'task';
    _saveSoon();
    _notify();
  }

  void archive({bool album = false}) {
    if (busy) return;
    phase = album ? 'album' : 'archive';
    _saveSoon();
    _notify();
  }

  void resume() {
    if (busy || active == null) return;
    phase = 'intro';
    _notify();
  }

  void choose(String id, {int slot = 0}) {
    if (busy ||
        task == null ||
        !task!.optionIds.contains(id) ||
        phase != 'task') {
      return;
    }
    final a = answers;
    if (task!.mechanic == 'route') {
      if (slot < 0 || slot >= task!.slots.length) return;
      while (a.length <= slot) {
        a.add('');
      }
      for (var i = 0; i < a.length; i++) {
        if (i != slot && a[i] == id) a[i] = '';
      }
      a[slot] = id;
      drafts[task!.id] = a;
    } else {
      drafts[task!.id] = [id];
    }
    message = '';
    _saveSoon();
    _notify();
  }

  void move(int index, int delta) {
    if (busy || task?.mechanic != 'timeline') return;
    final a = answers, next = index + delta;
    if (index < 0 || index >= a.length || next < 0 || next >= a.length) return;
    a.insert(next, a.removeAt(index));
    drafts[task!.id] = a;
    _saveSoon();
    _notify();
  }

  void hint() {
    hintOpen = !hintOpen;
    _saveSoon();
    _notify();
  }

  void next() {
    if (busy || phase != 'result') return;
    hintOpen = false;
    message = '';
    if (taskIndex == 0) {
      taskIndex = 1;
      start();
    } else {
      archive(album: true);
    }
  }

  Future<void> submit() async {
    if (busy || !canSubmit || phase != 'task') return;
    if (!task!.accepts(answers)) {
      message = 'Henüz doğru değil. İpucuna bakıp yeniden dene.';
      _notify();
      return;
    }
    busy = true;
    final id = task!.id;
    final wasSolved = solved.contains(id);
    solved.add(id);
    pending[id] = List<String>.from(answers);
    phase = 'result';
    message = '';
    try {
      await _save();
    } catch (_) {
      if (!wasSolved) solved.remove(id);
      phase = 'task';
      message = 'İlerleme kaydedilemedi. Yeniden dene.';
    } finally {
      busy = false;
      _notify();
    }
    if (phase == 'result') unawaited(sync());
  }

  void _merge(Map<String, dynamic> response) {
    if (response['version'] != catalog.version) {
      throw StateError('İçerik sürümü değişti. Uygulamayı güncelle.');
    }
    final ids = catalog.tasks.map((t) => t.id).toSet();
    confirmed.addAll(
      nostalgiaMap(response['completed']).keys.where(ids.contains),
    );
    solved.addAll(confirmed);
    hints.addAll(nostalgiaMap(response['hints']).keys.where(ids.contains));
    rewards = nostalgiaMap(response['rewards']);
    pro = response['pro'] == true;
    rewardEligible = response['rewardEligible'] == true;
  }

  String _error(Object e) {
    if (e is StateError) return e.message;
    if (e is FirebaseFunctionsException &&
        ['failed-precondition', 'permission-denied'].contains(e.code)) {
      return e.message ?? 'İşlem doğrulanamadı.';
    }
    return 'Çevrimdışı devam edebilirsin. İlerlemen cihazda; ödüller bağlantı gelince Eşitle ile doğrulanır.';
  }

  Future<void> sync() async {
    if (syncing || _disposed || !ready) return;
    syncing = true;
    _notify();
    try {
      await _save(); // Flush even when transport is offline.
      final status = await gateway.call('status');
      if (_disposed) return;
      _merge(status);
      for (final t in catalog.tasks) {
        if (!pending.containsKey(t.id)) continue;
        final reply = await gateway.call('submit', {
          'version': catalog.version,
          'taskId': t.id,
          'answers': pending[t.id],
        });
        if (_disposed) return;
        if (reply['correct'] != true) {
          throw StateError('Bekleyen görev doğrulanamadı. İçeriği güncelle.');
        }
        _merge(reply);
        pending.remove(t.id);
        await _save();
      }
      message = '';
      await _save();
    } catch (e) {
      if (!_disposed) message = _error(e);
    } finally {
      syncing = false;
      _notify();
    }
  }

  Future<void> strongHint() async {
    if (busy || syncing || task == null) return;
    if (hints.contains(task!.id)) return;
    busy = true;
    message = '';
    _notify();
    try {
      final reply = await gateway.call('hint', {
        'version': catalog.version,
        'taskId': task!.id,
      });
      if (_disposed) return;
      _merge(reply);
      await _save();
    } catch (e) {
      if (!_disposed) message = _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
