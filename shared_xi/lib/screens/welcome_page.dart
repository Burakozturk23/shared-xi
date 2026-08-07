import 'package:flutter/material.dart';

import 'daily_challenge_page.dart';
import 'match_type_selection_page.dart';
import 'endless_mode_selection_page.dart';
import 'chain_page.dart';
import 'grid_mode_selection_page.dart';
import 'random_five_page.dart';
import 'mystery_player_page.dart';
import 'odd_club_mode_selection_page.dart';
import 'blind_ranking_page.dart';
import 'career_puzzle_page.dart';
import 'higher_lower_mode_selection_page.dart';
import 'transfer_detective_page.dart';
import 'build_xi_theme_selection_page.dart';
import 'story_mode_selection_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 72,
                color: Colors.blue,
              ),

              const SizedBox(height: 12),

              const Text(
                "LINKBALL",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Hafızanla Bağla, Oyunu Çöz",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 32),

              const _SectionTitle("🔥 ÖNE ÇIKAN"),

              _ModeCard(
                title: "GÜNÜN MÜCADELESİ",
                subtitle: "Her gün yeni futbol bulmacası",
                icon: Icons.calendar_today,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DailyChallengePage(),
                    ),
                  );
                },
              ),

              const _SectionTitle("🎮 OYUN MODLARI"),

              _ModeCard(
                title: "SERİ MODU",
                subtitle: "5 can ile mümkün olduğunca ilerle",
                icon: Icons.bolt,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EndlessModeSelectionPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              const SizedBox(height: 16),

_ModeCard(
  title: "STORY MODE",
  subtitle: "8 farklı hikaye modu (yakında dolduracağız)",
  icon: Icons.auto_stories,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StoryModeSelectionPage(),
      ),
    );
  },
),

              _ModeCard(
                title: "ZİNCİR MODU",
                subtitle: "Kulüpler arasında oyuncu zinciri kur",
                icon: Icons.link,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChainPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              _ModeCard(
                title: "GRID MODU",
                subtitle: "3x3 futbol bulmacası",
                icon: Icons.grid_view,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const GridModeSelectionPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              _ModeCard(
                title: "RASTGELE BEŞLER",
                subtitle: "5 kulüp, ortak oyuncuları bul",
                icon: Icons.style,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const RandomFivePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

const SizedBox(height: 16),

_ModeCard(
  title: "SAHTE KULÜP",
  subtitle: "Oynamadığı kulübü bul, seriyi bozma",
  icon: Icons.image_not_supported,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OddClubModeSelectionPage(),
      ),
    );
  },
),
const SizedBox(height: 16),
const SizedBox(height: 16),

_ModeCard(
  title: "KÖRLEMESİNE SIRALAMA",
  subtitle: "Gelen oyuncuyu anında sırala, geri dönüş yok",
  icon: Icons.leaderboard,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BlindRankingPage(),
      ),
    );
  },
),
const SizedBox(height: 16),

_ModeCard(
  title: "CAREER PUZZLE",
  subtitle: "Oyuncuyu bil, kariyer rotasını doğru sırala",
  icon: Icons.route,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CareerPuzzlePage(),
      ),
    );
  },
),
const SizedBox(height: 16),

_ModeCard(
  title: "HIGHER OR LOWER",
  subtitle: "Piyasa değeri ya da gol, kim daha yüksek?",
  icon: Icons.compare_arrows,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HigherLowerModeSelectionPage(),
      ),
    );
  },
),

const SizedBox(height: 16),

_ModeCard(
  title: "TRANSFER DETECTIVE",
  subtitle: "İpuçlarından transferin oyuncusunu bul",
  icon: Icons.search,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransferDetectivePage(),
      ),
    );
  },
),
const SizedBox(height: 16),

_ModeCard(
  title: "BUILD XI 🧠",
  subtitle: "Tema seç, 100 puan bütçeyle kadro kur",
  icon: Icons.groups,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BuildXiThemeSelectionPage(),
      ),
    );
  },
),
_ModeCard(
  title: "MYSTERY PLAYER",
  subtitle: "İpuçlarından gizemli oyuncuyu bul",
  icon: Icons.help_outline,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MysteryPlayerPage(),
      ),
    );
  },
),

              const _SectionTitle("📚 KEŞFET"),

              _ModeCard(
                title: "VERİTABANI",
                subtitle: "Kulüp • Milli Takım • Lig",
                icon: Icons.storage,
                highlighted: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const MatchTypeSelectionPage(),
                    ),
                  );
                },
              ),

              const _SectionTitle("🌐 ONLINE"),

              _ModeCard(
                title: "VS MODU",
                subtitle: "Canlı düellolar (Yakında)",
                icon: Icons.people,
                locked: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("VS Modu çok yakında!"),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              const Center(
                child: Text(
                  "v1.0.0",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 28,
        bottom: 14,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlighted;
  final bool locked;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? Colors.amber
          : const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 30,
                color:
                    highlighted ? Colors.black : Colors.white,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: highlighted
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: highlighted
                            ? Colors.black87
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              locked
                  ? Icon(
                      Icons.lock,
                      color: highlighted
                          ? Colors.black54
                          : Colors.white54,
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: highlighted
                          ? Colors.black54
                          : Colors.white54,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}