import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/turkish_nostalgia_state.dart';
import '../services/turkish_nostalgia_service.dart';

class NostalgiaController extends ChangeNotifier {
  NostalgiaController({
    required this.catalog,
    required this.store,
    required this.gateway,
  });
  final NostalgiaCatalog catalog;
  final NostalgiaStore store;
  final NostalgiaGateway gateway;
  Map<String, dynamic> drafts = {},
      results = {},
      rewards = {},
      pending = {},
      albums = {},
      hints = {};
  String? activeId, badge;
  String phase = 'archive', message = '';
  bool busy = false, ready = false, hintOpen = false, rewardEligible = false;
  int hintPrice = 6;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  NostalgiaTask? get active =>
      activeId == null ? null : catalog.byId(activeId!);
  NostalgiaChapter? get chapter =>
      active == null ? null : catalog.chapter(active!.chapterId);
  List<String> get answers => nostalgiaStrings(drafts[activeId]);
  int get count => results.length;
  bool get canSubmit => active != null && validAnswers(active!, answers);
  bool validAnswers(NostalgiaTask t, List<String> a) =>
      a.length == t.required &&
      a.toSet().length == a.length &&
      a.every(t.optionIds.contains);
  bool available(String id) {
    final t = catalog.byId(id),
        first = catalog.chapter(catalog.byId(id).chapterId).taskIds.first;
    return t.id == first ||
        results.containsKey(first) ||
        pending.containsKey(first);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Map<String, dynamic> _snapshot() => {
    'version': catalog.version,
    'drafts': Map<String, dynamic>.from(drafts),
    'results': Map<String, dynamic>.from(results),
    'rewards': Map<String, dynamic>.from(rewards),
    'pending': Map<String, dynamic>.from(pending),
    'albums': Map<String, dynamic>.from(albums),
    'hints': Map<String, dynamic>.from(hints),
    'activeId': activeId,
    'phase': phase,
    'hintOpen': hintOpen,
    'badge': badge,
  };
  Future<void> _save() {
    final snapshot = _snapshot();
    final operation = _writes.then((_) => store.write(snapshot));
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  void _saveSoon() {
    _save().catchError((Object _) {
      message = 'Cihaz kaydı yazılamadı. Çıkmadan önce yeniden dene.';
      _notify();
    });
  }

  Future<void> load() async {
    final s = await store.read();
    if (_disposed) return;
    if (s['version'] == catalog.version) {
      final ids = catalog.tasks.map((t) => t.id).toSet();
      drafts = nostalgiaMap(s['drafts'])
        ..removeWhere((id, v) => !ids.contains(id));
      pending = nostalgiaMap(s['pending'])
        ..removeWhere(
          (id, v) =>
              !ids.contains(id) ||
              !validAnswers(catalog.byId(id), nostalgiaStrings(v)),
        );
      for (final t in catalog.tasks) {
        final a = nostalgiaStrings(drafts[t.id]);
        if (a.length > t.required ||
            a.where((s) => s.isNotEmpty).toSet().length !=
                a.where((s) => s.isNotEmpty).length ||
            a.any((id) => id.isNotEmpty && !t.optionIds.contains(id)))
          drafts.remove(t.id);
      }
      results = nostalgiaMap(s['results'])
        ..removeWhere((id, v) => !ids.contains(id) || v is! Map);
      albums = nostalgiaMap(s['albums']);
      hints = nostalgiaMap(s['hints']);
      rewards = nostalgiaMap(s['rewards']);
      activeId = ids.contains(s['activeId']) ? s['activeId'] as String : null;
      badge = s['badge'] as String?;
      phase =
          activeId != null &&
              [
                'intro',
                'task',
                'result',
                'queued',
                'album',
              ].contains(s['phase'])
          ? s['phase'] as String
          : 'archive';
      if (phase == 'result' && !results.containsKey(activeId) ||
          phase == 'album' && !albums.containsKey(chapter?.id))
        phase = 'task';
      if (phase == 'queued' && !pending.containsKey(activeId)) phase = 'task';
      hintOpen = s['hintOpen'] == true;
    }
    ready = true;
    _notify();
    await sync();
  }

  void openChapter(String id, {bool replay = false}) {
    if (busy) return;
    final ch = catalog.chapter(id);
    activeId = ch.taskIds.firstWhere(
      (t) => !results.containsKey(t),
      orElse: () => ch.taskIds.first,
    );
    if (replay) {
      activeId = ch.taskIds.first;
      drafts.remove(activeId);
    }
    phase = !replay && albums.containsKey(id) ? 'album' : 'intro';
    hintOpen = false;
    message = '';
    _saveSoon();
    _notify();
  }

  void resume() {
    if (busy || active == null) return;
    phase = pending.containsKey(activeId)
        ? 'queued'
        : results.containsKey(activeId)
        ? 'result'
        : 'task';
    startIfNeeded();
    _saveSoon();
    _notify();
  }

  void startIfNeeded() {
    if (active?.type == 'timeline' && !validAnswers(active!, answers))
      drafts[activeId!] = active!.optionIds;
  }

  void start() {
    if (busy || active == null) return;
    startIfNeeded();
    phase = 'task';
    _saveSoon();
    _notify();
  }

  void archive() {
    if (busy) return;
    phase = 'archive';
    _saveSoon();
    _notify();
  }

  void next() {
    if (busy || chapter == null) return;
    final ids = chapter!.taskIds;
    if (activeId == ids.first && available(ids.last)) {
      activeId = ids.last;
      hintOpen = false;
      phase = results.containsKey(activeId) ? 'result' : 'task';
      startIfNeeded();
    } else {
      phase = albums.containsKey(chapter!.id) ? 'album' : 'archive';
    }
    message = '';
    _saveSoon();
    _notify();
  }

  void choose(String id) {
    slot(0, id);
  }

  void slot(int index, String id) {
    if (busy ||
        active == null ||
        !active!.optionIds.contains(id) ||
        index < 0 ||
        index >= active!.required)
      return;
    final a = List<String>.generate(
      active!.required,
      (i) => i < answers.length ? answers[i] : '',
    );
    for (var i = 0; i < a.length; i++) {
      if (a[i] == id) a[i] = '';
    }
    a[index] = id;
    drafts[activeId!] = a;
    pending.remove(activeId);
    message = '';
    _saveSoon();
    _notify();
  }

  void move(int index, int delta) {
    if (busy || active?.type != 'timeline') return;
    final a = answers, next = index + delta;
    if (index < 0 || index >= a.length || next < 0 || next >= a.length) return;
    final value = a.removeAt(index);
    a.insert(next, value);
    drafts[activeId!] = a;
    pending.remove(activeId);
    _saveSoon();
    _notify();
  }

  void hint() {
    hintOpen = !hintOpen;
    _saveSoon();
    _notify();
  }

  void _merge(Map<String, dynamic> response) {
    if (response['version'] != catalog.version)
      throw StateError('İçerik sürümü değişti. Uygulamayı güncelle.');
    results = nostalgiaMap(response['results']);
    rewards = nostalgiaMap(response['rewards']);
    albums = nostalgiaMap(response['albums']);
    hints = nostalgiaMap(response['hints']);
    hintPrice = (response['hintPrice'] as num?)?.toInt() ?? 6;
    rewardEligible = response['rewardEligible'] == true;
    badge = response['badge'] as String?;
  }

  String _error(Object e) {
    if (e is FirebaseFunctionsException &&
        ['failed-precondition', 'permission-denied'].contains(e.code))
      return e.message ?? 'İşlem doğrulanamadı.';
    if (e is StateError) return e.message;
    return 'Sunucuya ulaşılamadı. Cevabın cihazda saklandı; bağlantı gelince Eşitle’ye dokun.';
  }

  Future<void> submit() async {
    if (busy || !canSubmit || !available(activeId!)) return;
    final id = activeId!;
    pending[id] = List<String>.from(answers);
    busy = true;
    message = '';
    _notify();
    var saved = false;
    try {
      await _save();
      saved = true;
      final first = chapter!.taskIds.first;
      if (id != first && !results.containsKey(first)) {
        phase = 'queued';
        message = 'Önceki cevapla birlikte doğrulama sırasında.';
        await _save();
        return;
      }
      final r = await gateway.call('submit', {
        'version': catalog.version,
        'taskId': id,
        'answers': pending[id],
      });
      if (_disposed) return;
      if (r['correct'] == true) {
        _merge(r);
        phase = 'result';
        message = 'Görev doğrulandı. İlk tamamlama ödülü bir kez verilir.';
      } else {
        phase = 'task';
        message =
            'Henüz doğru değil. Ücretsiz ipucuna bakıp yeniden deneyebilirsin.';
      }
      pending.remove(id);
      await _save();
    } catch (e) {
      if (!_disposed) {
        phase = saved ? 'queued' : 'task';
        message = saved ? _error(e) : 'Cihaz kaydı yazılamadı. Yeniden dene.';
        if (saved) _saveSoon();
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> sync() async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      final s = await gateway.call('status');
      if (_disposed) return;
      _merge(s);
      message = '';
      for (final task in catalog.tasks) {
        final id = task.id;
        if (!pending.containsKey(id)) continue;
        final first = catalog.chapter(task.chapterId).taskIds.first;
        if (id != first && !results.containsKey(first)) continue;
        final r = await gateway.call('submit', {
          'version': catalog.version,
          'taskId': id,
          'answers': pending[id],
        });
        if (_disposed) return;
        if (r['correct'] == true) {
          _merge(r);
          if (id == activeId && ['task', 'queued'].contains(phase))
            phase = 'result';
        } else {
          message =
              'Bekleyen bir cevap yanlış. İşaretli bölümü açıp yeniden dene.';
          if (id == activeId) phase = 'task';
        }
        pending.remove(id);
        await _save();
      }
      await _save();
    } catch (e) {
      if (!_disposed) message = _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> buyHint() async {
    if (busy || active == null) return;
    busy = true;
    message = '';
    _notify();
    try {
      final r = await gateway.call('hint', {
        'version': catalog.version,
        'taskId': activeId,
        'maxPrice': hintPrice,
      });
      if (_disposed) return;
      _merge(r);
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
