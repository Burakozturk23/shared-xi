import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/journey_task.dart';
import '../services/journey_v2_store.dart';

class JourneyV2Controller extends ChangeNotifier {
  JourneyV2Controller({required this.journey, required this.store, Random? random}) : random = random ?? Random();
  final JourneyV2Definition journey;
  final JourneyV2Store store;
  final Random random;
  JourneyCheckpoint? checkpoint;
  List<JourneyOption> options = const [];
  List<String> selected = [];
  bool busy = false, hintVisible = false, _disposed = false;
  String? message;
  JourneyTask get task => journey.tasks[checkpoint!.index];
  bool get locked => busy || checkpoint == null || checkpoint!.reviewing;
  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }
  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true; message = null; _notify();
    try { await action(); }
    catch (_) { message = 'İşlem kaydedilemedi. İlerlemen korunuyor; tekrar dene.'; }
    finally { busy = false; _notify(); }
  }
  Future<void> _save(JourneyCheckpoint next) async {
    next = JourneyCheckpoint(index: next.index, solved: next.solved,
      everCompleted: next.everCompleted || checkpoint?.everCompleted == true || checkpoint?.complete == true);
    await store.write(journey.id, next.toJson(journey));
    if (!_disposed) checkpoint = next;
  }
  void _prepare() {
    if (_disposed || checkpoint == null) return;
    options = task.shuffled(random); selected = []; hintVisible = false;
  }
  Future<void> initialize() => _run(() async {
    final raw = await store.read(journey.id);
    if (_disposed) return;
    checkpoint = raw == null ? const JourneyCheckpoint() : JourneyCheckpoint.fromJson(raw, journey);
    _prepare();
  });
  void choose(String key) {
    if (locked || !options.any((o) => o.key == key)) return;
    message = null;
    if (selected.contains(key)) {
      selected = [...selected]..remove(key);
    } else if (task.requiredCount == 1) {
      selected = [key];
    } else if (selected.length < task.requiredCount) {
      selected = [...selected, key];
    } else { message = 'Seçimini değiştirmek için önce seçili bir kartı kaldır.'; }
    _notify();
  }
  void move(int index, int delta) {
    if (locked || !task.isTimeline || index < 0 || index >= selected.length) return;
    final to = index + delta;
    if (to < 0 || to >= selected.length) return;
    final next = [...selected]; final item = next.removeAt(index); next.insert(to, item);
    selected = next; _notify();
  }
  void clear() { if (!locked) { selected = []; message = null; _notify(); } }
  void hint() { if (!locked) { hintVisible = true; _notify(); } }
  Future<void> submit() => _run(() async {
    if (checkpoint == null || checkpoint!.reviewing) return;
    if (selected.length != task.requiredCount) {
      message = task.isTimeline ? 'Önce tüm durakları rotaya ekle.' : '${task.requiredCount} seçim yap.'; return;
    }
    if (!task.accepts(selected)) {
      message = task.isTimeline ? 'Bu sıra uyuşmadı. Durakları değiştirip tekrar dene.' : 'Bu seçim döneme uymadı. Tekrar deneyebilirsin.'; return;
    }
    await _save(JourneyCheckpoint(index: checkpoint!.index, solved: checkpoint!.index + 1));
  });
  Future<void> next() => _run(() async {
    final state = checkpoint;
    if (state == null || !state.reviewing || state.complete) return;
    await _save(JourneyCheckpoint(index: state.index + 1, solved: state.solved));
    _prepare();
  });
  Future<void> restart() => _run(() async { await _save(const JourneyCheckpoint()); _prepare(); });
}
