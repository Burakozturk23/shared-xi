import 'package:flutter/material.dart';

class GameResultsPage extends StatelessWidget {
  final int score;
  final int total;
  final List<String> foundPlayers;
  final List<String> missedPlayers;

  const GameResultsPage({
    super.key,
    required this.score,
    required this.total,
    required this.foundPlayers,
    required this.missedPlayers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sonuçlar'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, size: 90, color: Colors.amber),
              const SizedBox(height: 20),
              Text(
                '$score / $total oyuncu bulundu',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('✅ Bulunan Oyuncular',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: foundPlayers.isEmpty
                    ? const Center(
                        child:
                            Text('Yok', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: foundPlayers.length,
                        itemBuilder: (context, index) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: Text(foundPlayers[index]),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('❌ Bulunamayan Oyuncular',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: missedPlayers.isEmpty
                    ? const Center(
                        child:
                            Text('Yok', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: missedPlayers.length,
                        itemBuilder: (context, index) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.cancel, color: Colors.red),
                          title: Text(missedPlayers[index]),
                        ),
                      ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('GERİ DÖN'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text('ANA MENÜ'),
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}