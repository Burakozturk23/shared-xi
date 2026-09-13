import 'package:flutter/material.dart';

import '../app/app_preferences.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/pitch_ui.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _step = 0;
  bool _saving = false;
  static const _titles = [
    'İki kulüp.\nTek bağlantı.',
    'Her gün\nyeni bir meydan okuma.',
    'Bağlantıyı\nsen seç.',
    'Futbolu bildiğin\ngibi oyna.',
  ];
  static const _bodies = [
    'Her iki kulüpte de forma giymiş futbolcuyu bul. Bağlantıyı tamamla.',
    'Günün eşleşmelerini çöz. Futbol bilgini her gün oyuna taşı.',
    'İki kulüp veya bir kulüp ve ülke seç. Merak ettiğin ortak futbolcuları keşfet.',
    'Bulmacaları çöz, kelimeleri bul, kendi kadronu kur. Hepsi Oyunlar’da.',
  ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int step) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(
        step,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await PreferencesScope.of(context).finishOnboarding();
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tercihin kaydedilemedi. Tekrar deneyebilirsin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return PopScope(
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _step > 0) _go(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
                child: Row(
                  children: [
                    const Expanded(child: BrandWordmark()),
                    TextButton(
                      onPressed: _saving ? null : _finish,
                      child: const Text('Atla'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: 4,
                  onPageChanged: (index) => setState(() => _step = index),
                  itemBuilder: (context, index) => SingleChildScrollView(
                    key: ValueKey('onboarding-$index'),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'FUTBOLUN ORTAK NOKTASI',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 24),
                        _Illustration(step: index),
                        const SizedBox(height: 32),
                        Semantics(
                          header: true,
                          child: Text(
                            _titles[index],
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _bodies[index],
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _step > 0
                          ? IconButton(
                              tooltip: 'Önceki adım',
                              onPressed: _saving ? null : () => _go(_step - 1),
                              icon: const Icon(Icons.arrow_back_rounded),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Semantics(
                        label: 'Tanıtım adımı',
                        value: '${_step + 1} / 4',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 4; i++)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: i == _step ? 16 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _step ? p.accent : p.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PitchAction(
                      label: _step == 3 ? 'Başlayalım' : 'Devam',
                      busy: _saving,
                      onPressed: _step == 3 ? _finish : () => _go(_step + 1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hesabını daha sonra bağlayabilirsin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    if (step == 3) {
      return PitchPanel(
        child: Column(
          children: [
            for (final (icon, title, caption) in const [
              (
                Icons.search_rounded,
                'Bilmeceyi çöz',
                'Mystery Player · Kadro Kasası',
              ),
              (
                Icons.text_fields_rounded,
                'Kelimelerle oyna',
                'Futbol Lingo · Passaparola',
              ),
              (
                Icons.groups_outlined,
                'Kendi takımını kur',
                'Squad Challenge · Club Manager',
              ),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.raised,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(icon, color: p.accent, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              caption,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return PitchPanel(
      child: Column(
        children: [
          if (step == 1) ...[
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: p.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Günün Maçları',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (step == 2) ...[
            Text(
              'Kulüp + Ülke',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: p.accent),
            ),
            const SizedBox(height: 24),
          ],
          PitchField(
            height: 176,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Badge(step == 2 ? 'barcelona' : 'arsenal'),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: p.tint,
                  child: Text(
                    step == 1 ? '?' : 'TH',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: p.accent),
                  ),
                ),
                step == 2
                    ? Semantics(
                        label: 'Fransa',
                        child: const Text(
                          '🇫🇷',
                          style: TextStyle(fontSize: 40),
                        ),
                      )
                    : const _Badge('barcelona'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step == 1 ? 'Her gün yeni bir ortak oyuncu.' : 'Thierry Henry',
            textAlign: TextAlign.center,
            style: step == 1
                ? Theme.of(context).textTheme.bodyMedium
                : Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            step == 2 ? 'Barcelona · Fransa' : 'Arsenal · Barcelona',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/onboarding_$name.png',
    semanticLabel: name == 'arsenal' ? 'Arsenal' : 'Barcelona',
    width: 48,
    height: 56,
    fit: BoxFit.contain,
  );
}
