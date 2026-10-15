import 'package:flutter/material.dart';

import '../app/route_appearance.dart';
import '../widgets/pitch_ui.dart';
import 'journey_passport_page.dart';
import 'what_if_selection_page.dart';
import 'ucl_moments_page.dart';
import 'turkish_nostalgia_page.dart';
import 'international_glory_page.dart';
import 'dynasties_page.dart';
import 'football_docu_page.dart';
import 'derby_day_page.dart';

class StoryCollectionsPage extends StatelessWidget {
  const StoryCollectionsPage({super.key, this.onOpen});
  final ValueChanged<Widget>? onOpen;
  static const collections = [
    (
      title: 'Kariyer Pasaportu',
      subtitle: 'Player Journey · Damgaların ve favori futbolcuların',
      icon: Icons.route_outlined,
      page: JourneyPassportPage(),
    ),
    (
      title: 'Kader Arşivi',
      subtitle: 'What If · Seçtiğin yollar ve alternatif sonlar',
      icon: Icons.alt_route_rounded,
      page: WhatIfPage(archive: true),
    ),
    (
      title: 'Avrupa Hatıraları',
      subtitle: 'UCL Moments · Tamamladığın Avrupa geceleri',
      icon: Icons.emoji_events_outlined,
      page: UclMomentsPage(openCollection: true),
    ),
    (
      title: 'Nostalji Albümü',
      subtitle: 'Türk futbolundan biriktirdiğin hatıralar',
      icon: Icons.collections_bookmark_outlined,
      page: TurkishNostalgiaPage(showAlbum: true),
    ),
    (
      title: 'Milletler Albümü',
      subtitle: 'International Glory · Millî takım yolculuğun',
      icon: Icons.public_rounded,
      page: InternationalGloryPage(openAlbum: true),
    ),
    (
      title: 'Hanedanlıklar Atlası',
      subtitle: 'Dynasties · Kazandığın takım mühürleri',
      icon: Icons.castle_outlined,
      page: DynastiesPage(openAtlas: true),
    ),
    (
      title: 'Belgesel Arşivi',
      subtitle: 'Football Docu-Series · Açtığın futbol dosyaları',
      icon: Icons.movie_filter_outlined,
      page: FootballDocuPage(openCollection: true),
    ),
    (
      title: 'Derbi Pasaportu',
      subtitle: 'Derby Day · Keşfettiğin rekabetler',
      icon: Icons.stadium_outlined,
      page: DerbyDayPage(openCollection: true),
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hikâye koleksiyonlarım')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Oynadıkça biriken hikâyeler.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Damgaların, kartların ve maç hatıraların tek yerde. Bir koleksiyon seç; kaldığın yerden devam et.',
        ),
        const SizedBox(height: 20),
        for (final entry in collections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PitchRow(
              title: entry.title,
              subtitle: entry.subtitle,
              icon: entry.icon,
              highlight: true,
              onTap: () {
                if (onOpen != null) {
                  onOpen!(entry.page);
                  return;
                }
                Navigator.of(context)
                    .push(LinkballRoute(builder: (_) => entry.page));
              },
            ),
          ),
      ],
    ),
  );
}
