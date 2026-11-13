import 'package:flutter/material.dart';

import '../online/online_mode_catalog.dart';
import 'friend_room_section.dart';

/// Friend rooms for the three Grid variants, shown in the Grid menus.
class GridFriendSection extends StatelessWidget {
  const GridFriendSection({super.key});

  @override
  Widget build(BuildContext context) => const FriendRoomSection(
    modes: [
      (
        OnlinePlayMode.gridClassic,
        'Klasik',
        'Sırayla oynanır · üçlü çizgi kazanır',
      ),
      (OnlinePlayMode.gridRandom, 'Rastgele', '5 kulüp çifti · nadir isim +1'),
      (
        OnlinePlayMode.gridReverse,
        'Tersten',
        'Ortak kriteri bul · 4 eksen kazanır',
      ),
    ],
  );
}
