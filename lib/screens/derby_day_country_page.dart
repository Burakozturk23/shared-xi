import 'package:flutter/material.dart';

import '../data/derby_data.dart';
import 'derby_day_list_page.dart';

class DerbyDayCountryPage extends StatelessWidget {
  const DerbyDayCountryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Derby Day')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: derbyCountries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final country = derbyCountries[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.flag, size: 30),
              title: Text(country.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('${country.derbies.length} derbi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DerbyDayListPage(country: country),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}