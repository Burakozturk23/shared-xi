import 'package:flutter/material.dart';
import '../models/club.dart';
import '../theme/ortak_saha_theme.dart';
import 'club_badge.dart';

/// Content-driven cards; use a single column for narrow accessibility layouts.
class FakeClubOptions extends StatelessWidget {
  const FakeClubOptions({super.key, required this.options, required this.onSelected,
    this.selectedId, this.fakeClubId, this.eliminated = const [], this.confirmed = const []});
  final List<Map<String, dynamic>> options;
  final ValueChanged<int>? onSelected;
  final int? selectedId, fakeClubId;
  final List<int> eliminated, confirmed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth < 360 && MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 2;
    return Column(children: [
      for (var i = 0; i < options.length; i += columns)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: 10),
            Expanded(child: i + column < options.length ? _card(context, options[i + column]) : const SizedBox()),
          ]],
        ))),
    ]);
  });
  Widget _card(BuildContext context, Map<String, dynamic> option) {
    final club = Club.fromJson(option), colors = PitchColors.of(context);
    final removed = eliminated.contains(club.id), verified = confirmed.contains(club.id);
    final revealed = fakeClubId != null, fake = fakeClubId == club.id, selected = selectedId == club.id;
    final label = revealed ? fake ? 'Sahte kulüp' : 'Oynadı' : removed ? 'Elendi · oynadı' : verified ? 'Doğrulandı · oynadı' : selected ? 'Seçildi' : 'Seç';
    final icon = revealed ? fake ? Icons.search_off : Icons.check_circle_outline :
      removed ? Icons.remove_circle_outline : verified ? Icons.verified_outlined : selected ? Icons.radio_button_checked : Icons.radio_button_off;
    return Semantics(button: true, selected: selected, label: '${club.name}, $label',
      child: Material(color: selected || fake ? colors.tint : colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected || fake ? colors.accent : colors.border)),
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
