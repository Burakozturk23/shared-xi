import 'dart:async';
import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/story_support_service.dart';
import 'paid_hint_button.dart';

/// The server chooses the pinned offer or preserved legacy/Pro entitlement.
class StorySupportPanel extends StatefulWidget {
  const StorySupportPanel({super.key, required this.mode, required this.targetId,
    required this.legacy, this.disabled = false, this.resultOnly = false, this.knownBasic, this.service});
  final String mode, targetId;
  final Widget legacy;
  final bool disabled, resultOnly;
  final String? knownBasic;
  final StorySupportService? service;
  @override
  State<StorySupportPanel> createState() => _StorySupportPanelState();
}
class _StorySupportPanelState extends State<StorySupportPanel> {
  late StorySupportService _service;
  Map<String, dynamic>? _value;
  String? _error;
  bool _busy = false;
  int _generation = 0;
  StreamSubscription<dynamic>? _auth;
  @override
  void initState() {
    super.initState(); _service = widget.service ?? StorySupportService();
    if (widget.service == null) _auth = AuthService.authStateChanges.listen((_) {
      _service = StorySupportService(); _load();
    });
    _load();
  }
  @override
  void didUpdateWidget(covariant StorySupportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.targetId != widget.targetId || oldWidget.service != widget.service) {
      _service = widget.service ?? StorySupportService(); _load();
    }
  }
  bool _active(int generation, String? uid) => mounted && generation == _generation && uid == _service.currentUser;
  Future<void> _load() async {
    final generation = ++_generation, uid = _service.currentUser;
    setState(() { _busy = true; _error = null; _value = null; });
    try {
      final value = uid == null ? <String, dynamic>{'legacy': true} : await _service.load(widget.mode, widget.targetId);
      if (_active(generation, uid)) setState(() { _value = value; });
    } catch (_) {
      if (_active(generation, uid)) setState(() { _error = 'Destek bilgisi yüklenemedi. Yenileyebilir veya oynamaya devam edebilirsin.'; });
    } finally {
      if (_active(generation, uid)) setState(() { _busy = false; });
    }
  }
  Map<String, dynamic> _input() => {'mode': widget.mode, 'targetId': widget.targetId,
    'contentVersion': _value!['contentVersion'], 'sessionId': rewardMap(_value!['session'])['id'],
    'revision': rewardMap(_value!['session'])['revision']};
  Future<void> _act(Map<String, dynamic> payment, {bool watch = false}) async {
    if (_busy || widget.disabled) return;
    final generation = _generation, uid = _service.currentUser;
    final input = {..._input(), ...payment};
    setState(() { _busy = true; _error = null; });
    try {
      if (watch) {
        await _service.watch(input);
        if (!_active(generation, uid)) return;
        final value = await _service.load(widget.mode, widget.targetId);
        if (_active(generation, uid)) setState(() { _value = value; });
      } else {
        final value = await _service.use(input);
        if (_active(generation, uid)) setState(() { _value = value; });
      }
    } catch (_) {
      if (_active(generation, uid)) setState(() {
        _error = 'İşlem doğrulanamadı. Yenile ile hesabındaki sonucu eşitle.';
      });
    } finally {
      if (_active(generation, uid)) setState(() { _busy = false; });
    }
  }
  @override
  void dispose() { _generation++; _auth?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.resultOnly) {
      return rewardMap(rewardMap(_value?['session'])['support'])['assisted'] == true
          ? const Text('Bu bölüm: Yardımlı') : const SizedBox.shrink();
    }
    if (_value?['legacy'] == true) return widget.legacy;
    final session = rewardMap(_value?['session']), support = rewardMap(rewardMap(_value?['session'])['support']);
    final products = support['products'] as List? ?? const [];
    final hints = rewardMap(_value?['hints']);
    if (widget.knownBasic != null) hints['boost_basic'] = widget.knownBasic;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) ...[
        Text(_error!), TextButton(onPressed: _busy ? null : _load, child: const Text('Destekleri yenile')),
      ],
      if (_value != null) ...[
        if (support['assisted'] == true) const Text('Bu bölüm: Yardımlı'),
        if (support['recoveryPending'] == true) const Text('Kullanılmayan reklam hakkın korunuyor. Çantanda yer açınca yenile.'),
        for (final raw in products) Builder(builder: (context) {
          final p = rewardMap(raw), sku = '${rewardMap(raw)['id']}';
          if (hints[sku] != null) return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${hints[sku]}'));
          return PaidHintButton(session: session, sku: sku,
            label: sku == 'boost_strong' ? 'Güçlü bilgi' : 'Bağlam ipucu',
            currentUser: () => _service.currentUser,
            disabled: _busy || widget.disabled || _error != null || _value!['completed'] == true || session['finished'] == true,
            onUse: _act, onWatch: p['ads'] == true ? () => _act({'boostId': sku}, watch: true) : null);
        }),
      ],
    ]);
  }
}
