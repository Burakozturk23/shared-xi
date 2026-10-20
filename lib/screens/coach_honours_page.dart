import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../models/coach.dart';
import '../models/coach_honours.dart';
import '../services/coach_honours_service.dart';
import '../widgets/coach_avatar.dart';
import '../widgets/game_ui.dart';
import '../widgets/pitch_ui.dart';

const _archiveNotice = 'Tarihsel kaynak arşivi • Kesin veri tarihi bilinmiyor. '
    'Kulüpler ve başarı sayıları kaynağın dönemine aittir; güncel kariyer toplamı değildir.';

class CoachHonoursPage extends StatefulWidget {
  const CoachHonoursPage({super.key, this.service, this.initialCoachId, this.initialQuery = ''});
  final CoachHonoursService? service;
  final String? initialCoachId;
  final String initialQuery;
  @override
  State<CoachHonoursPage> createState() => _CoachHonoursPageState();
}

class _CoachHonoursPageState extends State<CoachHonoursPage> {
  late final _service = widget.service ?? CoachHonoursService.instance;
  late final _query = TextEditingController(text: widget.initialQuery);
  CoachHonoursCatalog? _catalog;
  bool _loading = true, _error = false;
  String _filter = 'all';
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final catalog = await _service.load();
      if (!mounted) return;
      final matched = widget.initialCoachId == null ? null : catalog.forCoach(widget.initialCoachId!);
      setState(() {
        _catalog = catalog; _loading = false;
        if (matched != null) _query.text = matched.name;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _catalog?.coaches.where((c) => CoachHonoursService.matches(c, _query.text) &&
      (_filter == 'all' || (_filter == 'honours' ? c.honours.isNotEmpty : !c.hasTrophyRecord))).toList() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Hoca başarı arşivi')),
      body: GameContent(child: _loading ? const Center(child: CircularProgressIndicator()) :
        _error ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Text('Başarı arşivi yüklenemedi.'), const SizedBox(height: 16),
            PitchAction(label: 'Tekrar dene', onPressed: _load),
          ]))) : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: records.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const GameIntro(icon: Icons.emoji_events_outlined, title: 'Hocaların başarı defteri',
                message: 'Kupaları, ödülleri ve genç takım başarılarını keşfet. Bu arşivi çevrimdışı da inceleyebilirsin.'),
              const SizedBox(height: 12),
              const Text(_archiveNotice),
              const SizedBox(height: 16),
              TextField(controller: _query, onChanged: (_) => setState(() {}), decoration: InputDecoration(
                labelText: 'Hoca, kulüp veya kupa ara', prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(tooltip: 'Aramayı temizle', icon: const Icon(Icons.clear),
                  onPressed: () => setState(_query.clear)))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: {
                'all': 'Tümü', 'honours': 'Başarı kaydı var', 'missing': 'Kupa satırı eksik',
              }.entries.map((e) => ChoiceChip(label: Text(e.value), selected: _filter == e.key,
                onSelected: (_) => setState(() => _filter = e.key))).toList()),
              Padding(padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('${records.length} / ${_catalog!.coaches.length} teknik direktör')),
              if (records.isEmpty) const PitchPanel(child: Text(
                'Bu aramada kayıt bulunamadı. Aramayı veya filtreyi değiştir. Kaynak dosya tüm teknik direktörleri kapsamıyor.')),
            ]);
            final coach = records[index - 1];
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
              title: coach.name, icon: Icons.person_outline,
              leading: _avatar(coach),
              subtitle: '${coach.profile.snapshotClub ?? "Kulüp belirtilmemiş"} (kaynak dönemi)\n${coach.coverageLabel}',
              onTap: () => Navigator.of(context).push(LinkballRoute<void>(
                builder: (_) => CoachHonoursDetailPage(coach: coach))),
            ));
          },
        )),
    );
  }
}

Widget _avatar(CoachHonoursRecord c) => CoachAvatar(coach: Coach(
  id: c.coachId ?? c.id, name: c.name, countries: const [], clubIds: const []));

class CoachHonoursDetailPage extends StatelessWidget {
  const CoachHonoursDetailPage({super.key, required this.coach});
  final CoachHonoursRecord coach;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Başarı defteri')),
    body: GameContent(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _avatar(coach), const SizedBox(height: 16),
        Text(coach.name, style: Theme.of(context).textTheme.headlineSmall),
        if (coach.profile.citizenship != null) Text(coach.profile.citizenship!),
        if (coach.profile.birthDate != null) Text('Doğum: ${coach.profile.birthDate}'),
        const SizedBox(height: 12),
        Text('Kaynak dönemindeki kulüp: ${coach.profile.snapshotClub ?? "Belirtilmemiş"}'),
        if (coach.profile.snapshotLeague != null) Text('Kaynak ligi: ${coach.profile.snapshotLeague}'),
        if (coach.profile.snapshotFormation != null) Text('Kaynak dizilişi: ${coach.profile.snapshotFormation}'),
      ])),
      const SizedBox(height: 16), const Text(_archiveNotice),
      if (!coach.hasTrophyRecord || coach.honours.isEmpty) ...[
        const SizedBox(height: 16),
        PitchPanel(child: Text(!coach.hasTrophyRecord
          ? 'Bu teknik direktör için kaynakta kupa satırı bulunmuyor. Bu, hiç kupa kazanmadığı anlamına gelmez.'
          : 'Kaynakta adlandırılmış bir başarı kaydı yok. Bu, hiç kupa kazanmadığı anlamına gelmez.')),
      ],
      for (final category in coachHonourCategories.entries)
        if (coach.honours.any((h) => h.category == category.key)) ...[
          PitchSectionTitle(category.value),
          for (final honour in coach.honours.where((h) => h.category == category.key))
            Padding(padding: const EdgeInsets.only(bottom: 8), child: PitchPanel(child: Row(children: [
              const Icon(Icons.emoji_events_outlined), const SizedBox(width: 12),
              Expanded(child: Text(honour.label)), const SizedBox(width: 12),
              Text('×${honour.count}', semanticsLabel: '${honour.count} kez',
                style: Theme.of(context).textTheme.titleMedium),
            ]))),
        ],
      const PitchSectionTitle('Kaynak hakkında'),
      const Text('Teknik direktör ve kupa CSV arşivi. Kazanım yılları ve takımları belirtilmemiştir. '
        'Eksik alanlar sıfır kupa olarak değerlendirilmez.'),
      if ((coach.unclassifiedCount ?? 0) > 0) const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Kaynakta adı belirtilmeyen kayıtlar da var; kupa listesine dahil edilmedi.')),
    ])),
  );
}
