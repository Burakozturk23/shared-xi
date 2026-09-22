import 'package:flutter/material.dart';

import 'discovery_selection_page.dart';

class ClubCountrySelectionPage extends StatelessWidget {
  const ClubCountrySelectionPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const DiscoverySelectionPage(countryMode: true);
}
