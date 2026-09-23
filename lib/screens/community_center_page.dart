import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../services/social/social_gateways.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import 'friends_page.dart';
import 'leaderboard_page.dart';
import 'social_safety_center_page.dart';

class CommunityCenterPage extends StatefulWidget {
  const CommunityCenterPage({
    super.key,
    this.gateway = const CommunityGateway(),
  });
  final CommunityGateway gateway;
  @override
  State<CommunityCenterPage> createState() => _CommunityCenterPageState();
}

class _CommunityCenterPageState extends State<CommunityCenterPage>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _mode = TextEditingController();
  late final TabController _tabs;
  CommunityRequestCategory _category = CommunityRequestCategory.suggestion;
  List<CommunityRequest> _requests = [];
  bool _loading = true, _sending = false;
  String? _error;
  int _filter = 0;
  int _loadEpoch = 0;
  bool get _contextField =>
      _category == CommunityRequestCategory.bugReport ||
      _category == CommunityRequestCategory.matchmakingIssue;
  bool _active(CommunityRequest r) =>
      r.status == CommunityRequestStatus.open ||
      r.status == CommunityRequestStatus.reviewing;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _subject.dispose();
    _message.dispose();
    _mode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      await widget.gateway.prepare();
      final rows = await widget.gateway.listMine();
      if (mounted && epoch == _loadEpoch) setState(() => _requests = rows);
    } catch (error) {
      if (mounted && epoch == _loadEpoch)
        setState(() => _error = _friendly(error));
    } finally {
      if (mounted && epoch == _loadEpoch) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_sending || _form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await widget.gateway.prepare();
      final result = await widget.gateway.submit(
        category: _category,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        modeId: _contextField ? _mode.text.trim() : '',
      );
      if (!mounted) return;
      final r = result.submission;
      // Submit returns a summary; retain the full acknowledged message locally
      // even when refreshing history subsequently fails.
      setState(() {
        _requests = [
          CommunityRequest(
            submissionId: r.submissionId,
            category: r.category,
            subject: r.subject,
            message: _message.text.trim(),
            contextTag: r.contextTag,
            modeId: r.modeId,
            status: r.status,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
          ..._requests.where((item) => item.submissionId != r.submissionId),
        ];
        _subject.clear();
        _message.clear();
        _mode.clear();
        _filter = 0;
      });
      _tabs.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talebin alındı. Durumunu buradan takip edebilirsin.'),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendly(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendly(Object error) {
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'resource-exhausted' =>
          'Gönderim sınırına ulaştın. Bir süre sonra tekrar dene.',
        'invalid-argument' => 'Konu ve mesaj alanlarını kontrol et.',
        'unauthenticated' => 'Oturum hazırlanamadı. Tekrar dene.',
        _ =>
          'Bağlantı kurulamadı. Yazdıkların burada duruyor; tekrar deneyebilirsin.',
      };
    }
    return 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.';
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Topluluk Merkezi'),
      bottom: TabBar(
        isScrollable: MediaQuery.textScalerOf(context).scale(14) > 18,
        controller: _tabs,
        tabs: const [
          Tab(text: 'Merkez'),
          Tab(text: 'Taleplerim'),
        ],
      ),
    ),
    body: SafeArea(
      child: TabBarView(controller: _tabs, children: [_compose(), _history()]),
    ),
  );

  Widget _compose() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    children: [
      const SocialHero(
        icon: Icons.forum_outlined,
        eyebrow: 'LINKBALL TOPLULUĞU',
        title: 'Birlikte daha iyi bir oyun.',
        message:
            'Arkadaşlarınla buluş, rekabete katıl veya oyunu geliştirecek fikrini paylaş.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _open(const FriendsPage()),
            icon: const Icon(Icons.people_outline),
            label: const Text('Arkadaşlar'),
          ),
          OutlinedButton.icon(
            onPressed: () => _open(const LeaderboardPage()),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Sıralama'),
          ),
          OutlinedButton.icon(
            onPressed: () => _open(const SocialSafetyCenterPage()),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Güvenlik'),
          ),
        ],
      ),
      const PitchSectionTitle('Seni dinliyoruz'),
      Text(
        'Bir konu seç; talebinin durumunu Taleplerim bölümünde takip et.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in CommunityRequestCategory.values)
            ChoiceChip(
              label: Text(category.label),
              selected: _category == category,
              onSelected: _sending
                  ? null
                  : (_) => setState(() => _category = category),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('community-subject'),
              controller: _subject,
              enabled: !_sending,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Konu',
                hintText: 'Kısaca ne hakkında yazıyorsun?',
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 4 ? 'En az 4 karakter yaz.' : null,
            ),
            if (_contextField) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _mode,
                enabled: !_sending,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Oyun modu veya ekran (isteğe bağlı)',
                  hintText: 'Örn. Ortak oyuncu keşfi',
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('community-message'),
              controller: _message,
              enabled: !_sending,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Mesaj',
                alignLabelWithHint: true,
                hintText: _category == CommunityRequestCategory.bugReport
                    ? 'Ne yaptın, ne olmasını bekledin ve ne oldu?'
                    : 'Fikrini veya ihtiyacını bize anlat.',
              ),
              validator: (v) => (v?.trim().length ?? 0) < 10
                  ? 'En az 10 karakter yaz.'
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Gönderiliyor…' : 'Talebi gönder'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        widget.gateway.isGoogleAccount
            ? 'Bağlı profilinle gönderiyorsun.'
            : 'Misafir profilinle gönderiyorsun.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 6),
      Text(
        '15 dakikada en fazla 5, günde 20 talep gönderebilirsin. Mesajına şifre veya ödeme bilgisi ekleme.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _history() {
    final rows = _requests
        .where((r) => _filter == 0 || (_filter == 1 ? _active(r) : !_active(r)))
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          SocialHero(
            icon: Icons.inbox_outlined,
            eyebrow: 'TALEPLERİN',
            title: 'Sesin burada.',
            message:
                'Son taleplerinin durumunu gör. Ayrıntıları okumak için bir talebe dokun.',
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SocialStatus('${_requests.where(_active).length} açık'),
                SocialStatus(
                  '${_requests.where((r) => !_active(r)).length} tamamlanan',
                  complete: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, label) in [
                (0, 'Tümü'),
                (1, 'Açık'),
                (2, 'Tamamlanan'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == index,
                  onSelected: (_) => setState(() => _filter = index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            SocialNotice(
              title: 'Talepler yenilenemedi',
              message: _error!,
              icon: Icons.cloud_off_outlined,
              onAction: _loading ? null : _load,
            ),
            const SizedBox(height: 12),
          ],
          if (!_loading &&
              rows.isEmpty &&
              (_error == null || _requests.isNotEmpty))
            SocialNotice(
              title: _requests.isEmpty
                  ? 'Henüz bir talebin yok'
                  : 'Bu filtrede talep yok',
              message: _requests.isEmpty
                  ? 'Bir önerin veya sorun mu var? İlk talebini oluştur.'
                  : 'Diğer taleplerini görmek için filtreyi değiştir.',
              actionLabel: _requests.isEmpty
                  ? 'Talep oluştur'
                  : 'Tümünü göster',
              onAction: () {
                if (_requests.isEmpty) {
                  _tabs.animateTo(0);
                } else {
                  setState(() => _filter = 0);
                }
              },
            ),
          for (final request in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PitchPanel(
                onTap: () => _detail(request),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SocialStatus(
                          request.status.label,
                          complete: !_active(request),
                        ),
                        Text(
                          request.category.label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      request.subject,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      socialDate(request.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _detail(CommunityRequest r) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SocialStatus(r.status.label, complete: !_active(r)),
            const SizedBox(height: 16),
            Text(r.subject, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${r.category.label} · ${socialDate(r.createdAt)}'),
            if (r.modeId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.modeId),
            ],
            const SizedBox(height: 20),
            SelectableText(r.message),
            const SizedBox(height: 20),
            Text(
              'Son güncelleme: ${socialDate(r.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Talep no: ${r.submissionId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
