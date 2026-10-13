import 'package:flutter/material.dart';
import 'dynasties_page.dart';

/// Compatibility route: old shortcuts now open the same V2 Atlas.
class DynastiesPartSelectionPage extends StatelessWidget {
  const DynastiesPartSelectionPage({super.key});
  @override
  Widget build(BuildContext context) => const DynastiesPage();
}
