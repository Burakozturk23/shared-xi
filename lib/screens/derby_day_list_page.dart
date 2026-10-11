import 'package:flutter/material.dart';
import '../data/derby_data.dart';
import 'derby_day_page.dart';
/// Old country links now enter the atlas with that country selected.
class DerbyDayListPage extends StatelessWidget {
  const DerbyDayListPage({super.key,required this.country});
  final DerbyCountry country;
  @override
  Widget build(BuildContext context)=>DerbyDayPage(country:country.name);
}
