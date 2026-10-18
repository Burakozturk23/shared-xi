import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'daily_words.dart';
import 'rewarded_ad_models.dart';

/// Offline predictions never grant currency or update canonical records. The
/// server replays the same identities/actions and bounded monotonic durations.
class BurstOffline {
  BurstOffline(this.kit);
  final Map<String, dynamic> kit;
  Map<String, dynamic> get players => rewardMap(kit['players']);
  List<Map<String, dynamic>> get questions => (kit['questions'] as List).map(rewardMap).toList();
  int n(Object? value) => (value as num?)?.toInt() ?? 0;
  List<String> ids(Object? value) => (value as List? ?? []).map((x) => '$x').toList();
  List<Map<String, dynamic>> search(String query) {
    final key = dailyWordKey(query); if (key.length < 2) return [];
    final found = players.values.map(rewardMap).where((p) => ['${p['name']}', ...ids(p['aliases'])]
      .any((s) => dailyWordKey(s).contains(key))).toList();
    found.sort((a,b) {
      final aa = dailyWordKey('${a['name']}'), bb = dailyWordKey('${b['name']}');
      final priority = (bb.startsWith(key) ? 1 : 0) - (aa.startsWith(key) ? 1 : 0);
      return priority != 0 ? priority : aa.compareTo(bb) != 0 ? aa.compareTo(bb) : '${a['id']}'.compareTo('${b['id']}');
    });
    return found.take(12).map((p) => {...p, 'type': 'player'}).toList();
  }
  Map<String, dynamic> apply(Map<String, dynamic> source, Map<String, dynamic> event) {
    final r = rewardMap(jsonDecode(jsonEncode(source)));
    if (r['mode'] != 'burst' || r['phase'] != 'active' || r['finished'] == true || r['dataVersion'] != kit['version']) {
      throw StateError('Bu kayıt çevrimdışı ilerletilemiyor. Yenile ile bağlan.');
    }
    final elapsed = n(event['elapsedMs']); if (elapsed < 0) throw StateError('Geçersiz süre.');
    r['message'] = '';
    Map<String, dynamic> question() => questions.firstWhere((q) => q['id'] == rewardMap(r['question'])['id']);
    List<String> found() => (r['found'] as List? ?? []).map((p) => '${rewardMap(p)['id']}').toList();
    void end(String message, {bool won = false}) {r['finished'] = true; r['won'] = won; r['reason'] = message;}
    void archive(String cause) {
      final q = question(); final all = List<Map<String, dynamic>>.from((r['offlineHistory'] as List? ?? []).map(rewardMap));
      all.add({'questionId': q['id'], 'title': '${q['left']} × ${q['right']}', 'cause': cause,
        'missed': ids(q['answers']).where((id) => !found().contains(id)).map((id) => rewardMap(players[id])['name']).toList()});
      r['offlineHistory'] = all;
    }
    void next() {
      final used = ids(r['roundIds']); final tier = ['easy','normal','hard','legend'][(n(r['rounds']) ~/ 3).clamp(0,3).toInt()];
      final choices = questions.where((q) => q['pairType'] == r['pairType'] && !used.contains(q['id']) &&
        (r['style'] == 'speed' || q['difficulty'] == tier)).map((q) => (q: q,
          rank: sha256.convert(utf8.encode('${r['id']}:${used.length}:${q['id']}')).toString())).toList();
      choices.sort((a,b) => a.rank.compareTo(b.rank));
      if (choices.isEmpty) {end('Doğrulanmış soru havuzu tükendi.'); return;}
      final q = choices.first.q;
      r['question'] = {for (final k in ['id','left','right','difficulty']) k: q[k]};
      r['roundIds'] = [...used, q['id']]; r['found'] = []; r['hintedIds'] = []; r['hint'] = ''; r['roundAt'] = r['activeMs'];
    }
    void timeCheck() {
      if (r['style'] != 'speed') return;
      if (n(r['activeMs']) + n(r['penaltyMs']) >= 120000) end('Toplam süre doldu.');
      else if (n(r['activeMs']) - n(r['roundAt']) >= 30000) {archive('timeout'); r['streak'] = 0; next(); r['message'] = 'Tur süresi doldu. Yeni tur.';}
    }
    if (r['paused'] != true) r['activeMs'] = n(r['activeMs']) + elapsed;
    timeCheck();
    final action = '${event['action']}';
    if (r['finished'] != true) {
      if (action == 'finish') {archive('end'); end('Oyunu bitirdin.');}
      else if (action == 'pause') {r['paused'] = true;}
      else if (action == 'resume') {r['paused'] = false;}
      else if (action != 'tick') {
        if (r['paused'] == true) throw StateError('Önce oyuna devam et.');
        if (event['questionId'] != rewardMap(r['question'])['id']) throw StateError('Tur değişti. Güncel soruya cevap ver.');
        if (action == 'pass') {
          if (n(r['passes']) >= 2) throw StateError('İki pas hakkın kullanıldı.');
          r['passes'] = n(r['passes']) + 1; r['streak'] = 0;
          if (r['style'] == 'speed') r['penaltyMs'] = n(r['penaltyMs']) + 5000;
          archive('pass'); next();
        } else if (action == 'hint') {
          if (r['style'] != 'survival') throw StateError('Hız Atağı ipucu içermez.');
          final hinted = ids(r['hintedIds']);
          final candidates = ids(question()['answers']).where((id) => !found().contains(id) && !hinted.contains(id) &&
            '${rewardMap(players[id])['countryId'] ?? ''}'.isNotEmpty);
          if (candidates.isEmpty) throw StateError('Yeni ipucu kalmadı.');
          if (r['freeUsed'] != true) {r['freeUsed'] = true;}
          else if (n(r['adCredits']) > 0) {r['adCredits'] = n(r['adCredits']) - 1;}
          else {throw StateError('Doğrulanmış reklam ipucu gerekli.');}
          final id = candidates.first; final p = rewardMap(players[id]); r['hintedIds'] = [...hinted,id];
          r['hints'] = n(r['hints']) + 1;
          r['hint'] = '${'${p['name']}'.split(RegExp(r'\s+')).map((w) => '${w[0]}.').join(' ')} · ${p['country']}';
        } else if (action == 'answer') {
          String? id = event['entityId']?.toString();
          if (id == null) {
            final key = dailyWordKey('${event['query'] ?? ''}');
            final matches = players.values.map(rewardMap).where((p) => ['${p['name']}', ...ids(p['aliases'])]
              .any((s) => dailyWordKey(s) == key)).toList();
            if (key.isNotEmpty && matches.length == 1) id = '${matches.first['id']}';
          }
          if (id == null || !players.containsKey(id)) {r['message'] = 'Oyuncu bulunamadı veya ad belirsiz. Ceza yok.';}
          else if (found().contains(id)) {r['message'] = 'Bu oyuncuyu zaten buldun.';}
          else if (!ids(question()['answers']).contains(id)) {
            r['wrong'] = n(r['wrong']) + 1; r['streak'] = 0;
            if (r['style'] == 'speed') {r['penaltyMs'] = n(r['penaltyMs']) + 3000;} else {r['lives'] = n(r['lives']) - 1;}
            r['message'] = r['style'] == 'speed' ? 'Bu eşleşme doğru değil. −3 saniye.' : 'Bu eşleşme doğru değil. −1 can.';
          } else {
            r['found'] = [...(r['found'] as List? ?? []), {'id':id, 'name': rewardMap(players[id])['name']}];
            r['correct'] = n(r['correct']) + 1; r['streak'] = n(r['streak']) + 1;
            if (n(r['streak']) > n(r['bestStreak'])) r['bestStreak'] = r['streak'];
            r['score'] = n(r['score']) + (n(r['streak']) >= 10 ? 200 : n(r['streak']) >= 5 ? 150 : 100);
            if (found().length == 3) {
              r['rounds'] = n(r['rounds']) + 1; r['score'] = n(r['score']) + 50; archive('complete');
              if (r['style'] == 'survival' && n(r['rounds']) >= 12) {end('12 tur tamamlandı!', won: true);}
              else {next(); r['message'] = '3/3 · +50 tur bonusu!';}
            }
          }
          if (n(r['lives']) <= 0) end('Canların bitti.');
        } else {throw StateError('Geçersiz çevrimdışı işlem.');}
        timeCheck();
      }
    }
    r['revision'] = n(r['revision']) + 1;
    r['totalRemainingMs'] = (120000 - n(r['activeMs']) - n(r['penaltyMs'])).clamp(0,120000);
    r['roundRemainingMs'] = (30000 - n(r['activeMs']) + n(r['roundAt'])).clamp(0,30000);
    r['serverNow'] = n(r['serverNow']) + elapsed;
    r['earnedCoins'] = 0; r['pendingValidation'] = true;
    if (r['finished'] == true) {
      if (!(r['offlineHistory'] as List? ?? []).any((h) => rewardMap(h)['questionId'] == question()['id'])) archive('end');
      r['history'] = r['offlineHistory'] ?? [];
    }
    return r;
  }
}
