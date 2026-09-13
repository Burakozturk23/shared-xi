import 'package:flutter/material.dart';

import '../models/club.dart';
import 'discovery_selection_page.dart';

class ClubSelectionPage extends StatelessWidget {
  const ClubSelectionPage({super.key, this.prefillClub});
  final Club? prefillClub;
  @override
  Widget build(BuildContext context) =>
      DiscoverySelectionPage(prefillClub: prefillClub);
}
