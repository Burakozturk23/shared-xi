import 'package:flutter/material.dart';
import '../models/club.dart';
import 'club_badge.dart';

/// Two columns with content-driven height, including at large text scales.
class FakeClubOptions extends StatelessWidget {
  const FakeClubOptions({super.key, required this.options, required this.onSelected,
    this.selectedId, this.fakeClubId, this.eliminated = const [], this.confirmed = const []});
  final List<Map<String, dynamic>> options;
  final ValueChanged<int>? onSelected;
  final int? selectedId, fakeClubId;
  final List<int> eliminated, confirmed;

  @override
  Widget build(BuildContext context) => Column(children: [
    for (var i = 0; i < options.length; i += 2)
      Padding(padding: const EdgeInsets.only(bottom: 10), child: IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: _card(context, options[i])), const SizedBox(width: 10),
          Expanded(child: i + 1 < options.length ? _card(context, options[i + 1]) : const SizedBox())],
      ))),
  ]);
  Widget _card(BuildContext context, Map<String, dynamic> option) {
    final club = Club.fromJson(option), colors = Theme.of(context).colorScheme;
    final removed = eliminated.contains(club.id), verified = confirmed.contains(club.id);
    final revealed = fakeClubId != null, fake = fakeClubId == club.id, selected = selectedId == club.id;
    final label = revealed ? fake ? 'Sahte kulüp' : 'Oynadı' : removed ? 'Elendi · oynadı' : verified ? 'Doğrulandı · oynadı' : selected ? 'Seçildi' : 'Seç';
    final icon = revealed ? fake ? Icons.search_off : Icons.check_circle_outline :
      removed ? Icons.remove_circle_outline : verified ? Icons.verified_outlined : selected ? Icons.radio_button_checked : Icons.radio_button_off;
    return Semantics(button: true, selected: selected, label: '${club.name}, $label',
      child: Material(color: selected || fake ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected || fake ? colors.primary : colors.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onSelected == null || removed || verified ? null : () => onSelected!(club.id),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClubBadge(club: club, size: 42), const SizedBox(height: 10),
            Text(club.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8), Icon(icon, size: 20), const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
          ])),
        ),
      ));
  }
}
