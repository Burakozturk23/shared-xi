import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/energy_service.dart';
import '../models/rewarded_ad_models.dart';
import 'pitch_ui.dart';

String energyError(Object e) => e is FirebaseFunctionsException
    ? e.message ?? 'Bağlantı kurulamadı. Tekrar dene.'
    : e.toString().replaceFirst('Bad state: ', '');

Future<void> showEnergySheet(BuildContext context) => showModalBottomSheet<void>(
  context: context, isScrollControlled: true, showDragHandle: true,
  builder: (_) => const EnergySheet(),
);

/// A single guard prevents duplicate taps while the server reserves/confirms.
class StoryEnergyAccess {
  static bool _busy = false;
  static Future<bool> open(BuildContext context, String mode, String id) async {
    if (_busy) return false;
    _busy = true;
    try {
      await EnergyService().openStory(mode, id, isActive: () => context.mounted);
      return context.mounted;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(energyError(e))));
        if (e is FirebaseFunctionsException && e.code == 'resource-exhausted') await showEnergySheet(context);
      }
      return false;
    } finally { _busy = false; }
  }
}

class EnergySheet extends StatefulWidget {
  const EnergySheet({super.key, this.initialData});
  final Map<String, dynamic>? initialData;
  @override
  State<EnergySheet> createState() => _EnergySheetState();
}
class _EnergySheetState extends State<EnergySheet> {
  final service = EnergyService();
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  @override
  void initState() { super.initState(); data = widget.initialData; if (data == null) _run(() async { data = await service.status(); }); }
  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try { await action(); } catch (e) { error = energyError(e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _purchase(String package, int coins, int energy) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('+$energy enerji'), content: Text('$coins Link Coin harcanacak. Devam edilsin mi?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Onayla'))]));
    if (yes != true || !mounted) return;
    await _run(() async {
      data = await service.purchase(package);
    });
  }
  @override
  Widget build(BuildContext context) {
    final d = data;
    final daily = rewardMap(d?['daily']);
    final balance = (d?['balance'] as num?)?.toInt() ?? 6;
    final enabled = d?['enabled'] == true;
    final pro = d?['pro'] == true;
    final until = ((d?['nextRefillAt'] as num?)?.toInt() ?? 0) - ((d?['serverNow'] as num?)?.toInt() ?? 0);
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const Icon(Icons.bolt_rounded), const SizedBox(width: 8),
          Expanded(child: Text('Oyun enerjin', style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(tooltip: 'Yenile', onPressed: busy ? null : () => _run(() async { data = await service.status(); }), icon: const Icon(Icons.refresh))]),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!)),
        if (d != null) ...[
          const SizedBox(height: 20), Text('$balance / 6', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8), LinearProgressIndicator(value: balance / 6),
          const SizedBox(height: 12),
          Text(!enabled ? 'Enerji sistemi henüz etkin değil. Oyunlarına devam edebilirsin.' :
            until > 0 ? 'Sonraki enerji yaklaşık ${(until / 60000).ceil()} dakika sonra. Saatte +1, en fazla 6.' : 'Enerjin dolu. İlk oyundan sonra saatte +1 yenilenir.'),
          if ((d['reserved'] as num? ?? 0) > 0) Text('${d['reserved']} enerji başlayan oyun için ayrıldı.'),
          const SizedBox(height: 20),
          if (enabled) ...[
            FilledButton.icon(onPressed: busy || balance > 4 || (daily['ads'] as num? ?? 0) >= 2 ? null : () => _run(() async {
              await service.watch('energy_refill', pro: pro); data = await service.status();
            }), icon: Icon(pro ? Icons.bolt : Icons.play_circle_outline),
              label: Text('${pro ? 'Reklamsız bonus' : 'Reklam izle'} · +2 enerji (${daily['ads'] ?? 0}/2)')),
            if (pro) OutlinedButton(onPressed: busy || balance > 4 || daily['pro'] == true ? null : () => _run(() async {
              data = await service.call('claimProEnergyBonus');
            }), child: const Text('Pro günlük hediyesi · +2 enerji')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: busy || balance > 4 || (daily['purchases'] as num? ?? 0) >= 2 ? null : () => _purchase('small', 25, 2), child: const Text('+2 enerji · 25 Link Coin')),
            OutlinedButton(onPressed: busy || balance > 1 || (daily['purchases'] as num? ?? 0) >= 2 ? null : () => _purchase('large', 60, 5), child: const Text('+5 enerji · 60 Link Coin')),
            Text('Coin dolumu: ${daily['purchases'] ?? 0}/2. Günlük haklar İstanbul saatiyle 00.00’da yenilenir.'),
          ],
          const SizedBox(height: 20),
          const PitchPanel(child: Text('Enerjin bitse de oyun devam eder.\nGünün Sorusu, Günün Futbolcusu, Günün Maçları ve online maçlar ücretsiz.\n\nHikâyede açtığın içeriklere dönüş ve tekrar oynama ücretsizdir.')),
        ],
      ])));
  }
}
